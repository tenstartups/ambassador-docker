#!/usr/bin/env ruby
#
# This is a wrapper script around docker compose, providing additional commands
# specific to how this project is run in development
#
require 'active_support'
require 'active_support/core_ext'
require 'awesome_print'
require 'colorize'
require 'pty'

TCP_TUNNEL_REGEX = /^\s*TCP_TUNNEL_(?<tunnel_name>[_A-Z0-9]+_(?<bind_port>[0-9]+))=(?<service_host>[^:]+):(?<service_port>[0-9]+)\s*$/
SSH_TUNNEL_REGEX = /^\s*SSH_((?<tunnel_type>REMOTE|LOCAL)_)?TUNNEL_(?<tunnel_name>[_A-Z0-9]+_(?<bind_port>[0-9]+))=(?<service_host>[^:]+):(?<service_port>[0-9]+)\[((?<ssh_user>[^@]+)@)?(?<ssh_host>[^:]+)(:(?<ssh_port>[0-9]+))?\]\s*$/
SSH_IDENTITY_FILE = ENV['SSH_IDENTITY_FILE'] || "#{ENV['HOME']}/.ssh/id_rsa"
SSH_SERVER_CHECK_INTERVAL = (ENV['SSH_SERVER_CHECK_INTERVAL'] || 30).to_i
DEFAULT_BIND_ADDRESS = '0.0.0.0'.freeze

# Main tunnel manager process which starts and manages all tunnels
class TunnelManager
  include Singleton

  def initialize
    # Initialize the output print mutex
    @thread_manager_mutex = Mutex.new

    # Initialize tunnels array
    @tunnels = []

    # Initialize an array of output colors
    @output_colors = String.respond_to?(:colors) ? String.colors.dup.shuffle - %i(yellow red black white) : []

    # Create TCP tunnel handlers
    ENV.keys.map { |k| TCP_TUNNEL_REGEX.match("#{k}=#{ENV.fetch(k)}") }.compact.each do |match|
      tunnel_options = Hash[match.names.zip(match.captures)].symbolize_keys.merge(bind_address: DEFAULT_BIND_ADDRESS)
      tunnel = TcpTunnelHandler.new(**tunnel_options)
      tunnel.output_color = @output_colors.shift
      @tunnels << tunnel
    end

    # Create SSH tunnel handlers
    ENV.keys.map { |k| SSH_TUNNEL_REGEX.match("#{k}=#{ENV.fetch(k)}") }.compact.each do |match|
      tunnel_options = Hash[match.names.zip(match.captures)].symbolize_keys.merge(bind_address: DEFAULT_BIND_ADDRESS)
      tunnel = SshTunnelHandler.new(**tunnel_options)
      tunnel.output_color = @output_colors.shift
      @tunnels << tunnel
    end
  end

  def start
    output 'Press CTRL-C at any time to close all tunnels and exit'.colorize(:red)

    # Trap CTRL-C
    Signal.trap('INT') do
      puts "\nCTRL-C detected, waiting for all threads to exit gracefully...".colorize(:yellow)
      shutdown_wait unless @tunnels.empty?
      exit 0
    end

    # Trap SIGTERM
    Signal.trap('TERM') do
      puts "\nKill detected, waiting for all threads to exit gracefully...".colorize(:yellow)
      shutdown_wait unless @tunnels.empty?
      exit 1
    end

    # Start tunnels
    @tunnels.each(&:start)

    # Enter an indefinite wait loop until a signal is received
    loop { sleep 0.1 }
  end

  def tunnel_output(tunnel, message)
    @thread_manager_mutex.synchronize do
      puts "#{tunnel_name_padded(tunnel)} |".colorize(tunnel.output_color || :default) + ' ' + (message || '')
    end
  end

  private

  # Signal all threads to shutdown and wait gracefully for them.
  def shutdown_wait
    @tunnels.each(&:signal_exit)
    @tunnels.each(&:join)
  end

  def output(message)
    puts((message || '').to_s)
  end

  def tunnel_name_padded(tunnel)
    format("%-#{@tunnels.map { |t| t.tunnel_name.length }.max}s", tunnel.tunnel_name)
  end
end

class TunnelHandler
  class << self
    # Find a system command and throw an exception if not found
    # Filter out scripts from the same directory as this script since this script
    # is a shim for an actual system command
    def find_executable(bin, required = true)
      (capture_command("which -a #{bin}") || '')
        .split("\n")
        .map(&:strip)
        .uniq
        .first ||
        (
          if required
            message = "Required executable #{bin} not found, make sure it is available on your system PATH"
            puts message.colorize(:red)
            raise message
          end
        )
    end

    # Capture the result of a command and convert to nil if empty
    def capture_command(cmd)
      (result = `#{cmd}`.strip).empty? ? nil : result
    end

    # Kill a process by pid if it exists
    def kill_process(pid)
      pid && Process.kill('TERM', pid) rescue nil
    end
  end

  attr_accessor :tunnel_pid,
                :tunnel_name,
                :bind_address,
                :bind_port,
                :service_host,
                :service_port,
                :output_color,
                :exit_signalled

  def initialize(tunnel_name:, bind_address:, bind_port:, service_host:, service_port:)
    self.tunnel_name = tunnel_name
    self.bind_address = bind_address
    self.bind_port = bind_port
    self.service_host = service_host
    self.service_port = service_port
  end

  def start
    @thread = Thread.new { run }
  end

  def join
    @thread.join
  end

  def description
    "#{bind_address}:#{bind_port} => #{service_host}:#{service_port}"
  end

  def signal_exit
    self.exit_signalled = true
  end

  private

  # Run and individual tunnel with and make sure the it stays up.
  # This will loop until the signal_exit method is called
  def run
    output "Opening tunnel #{description}"
    open_tunnel
    next_retry = nil

    loop do
      # Exit from the loop if an exit is signalled
      break if exit_signalled

      # Restart the tunnel if no longer running
      unless process_running?
        next_retry ||= Time.now
        if Time.now >= next_retry
          output "Restarting tunnel #{description}"
          kill_tunnel
          open_tunnel
          next_retry = Time.now + 15
        end
      end

      # Sleep short for loop
      sleep 0.1
    end

    output "Closing tunnel #{description}"
    kill_tunnel
  end

  # Open a tunnel and capture output with a separate thread
  def open_tunnel
    PTY.spawn(*tunnel_command) do |stdout, _stdin, pid|
      self.tunnel_pid = pid
      Thread.new do
        begin
          stdout.each { |line| output(line) }
        rescue Errno::EIO
          # Do nothing on EOF, just exit quietly
        end
      end
    end
    Process.detach(tunnel_pid)
  end

  def kill_tunnel
    self.class.kill_process(tunnel_pid)
  end

  # Check if the tunnel process is running
  def process_running?
    tunnel_pid && Process.kill(0, tunnel_pid) rescue nil
  end

  def output(message)
    TunnelManager.instance.tunnel_output(self, message)
  end
end

class TcpTunnelHandler < TunnelHandler
  def initialize(tunnel_name:, bind_address:, bind_port:, service_host:, service_port:)
    super(
      tunnel_name: tunnel_name,
      bind_address: bind_address,
      bind_port: bind_port,
      service_host: service_host,
      service_port: service_port
    )
  end

  def tunnel_command
    command = []
    command << self.class.find_executable('socat')
    command += Array.new(ENV['SOCAT_DEBUG_LEVEL'].to_i) { '-d' }
    command << "TCP-LISTEN:#{bind_port},bind=#{bind_address},fork"
    command << "TCP:#{service_host}:#{service_port},reuseaddr"
    command
  end
end

class SshTunnelHandler < TunnelHandler
  attr_accessor :is_reverse,
                :ssh_user,
                :ssh_host,
                :ssh_port

  def initialize(tunnel_type: nil, tunnel_name:, bind_address:, bind_port:, service_host:, service_port:, ssh_user: nil, ssh_host:, ssh_port: nil)
    self.is_reverse = tunnel_type == 'REMOTE'
    self.ssh_user = ssh_user || ENV['SSH_USER']
    self.ssh_host = ssh_host
    self.ssh_port = ssh_port || ENV['SSH_PORT']
    super(
      tunnel_name: tunnel_name,
      bind_address: bind_address,
      bind_port: bind_port,
      service_host: service_host,
      service_port: service_port
    )
  end

  def description
    if is_reverse
      "#{service_host}:#{service_port} <= #{bind_address}:#{bind_port} (via #{ssh_user}@#{ssh_host}:#{ssh_port})"
    else
      "#{bind_address}:#{bind_port} => #{service_host}:#{service_port} (via #{ssh_user}@#{ssh_host}:#{ssh_port})"
    end
  end

  def tunnel_command
    command = []
    command += [self.class.find_executable('sshpass'), '-p', ENV['SSH_PASSWORD']] if ENV['SSH_PASSWORD']
    command += [self.class.find_executable('autossh'), '-M', '0', '-T', '-N']
    command += Array.new(ENV['SSH_VERBOSE_LEVEL'].to_i) { '-v' }
    command += ['-o', 'StrictHostKeyChecking=no']
    command += ['-o', 'UserKnownHostsFile=/dev/null']
    command += ['-o', "ServerAliveInterval=#{ENV['SSH_SERVER_CHECK_INTERVAL']}"] if ENV['SSH_SERVER_CHECK_INTERVAL']
    command += ['-o', "Port=#{ssh_port}"]
    command += ['-o', "User=#{ssh_user}"]
    command += ['-o', 'PasswordAuthentication=no'] unless ENV['SSH_PASSWORD']
    command += ['-o', "IdentityFile=\"#{ENV['SSH_IDENTITY_FILE']}\""] if ENV['SSH_IDENTITY_FILE']
    command << (is_reverse ? '-R' : '-L')
    command += ["#{bind_address}:#{bind_port}:#{service_host}:#{service_port}", ssh_host]
    command
  end
end

# Start the tunnel manager
TunnelManager.instance.start
