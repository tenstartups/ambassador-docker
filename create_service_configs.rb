#!/usr/bin/env ruby
require 'awesome_print'
require 'erb'
require 'ostruct'

TCP_TUNNEL_REGEX = /^\s*(?<tunnel_name>TCP_TUNNEL_[_A-Z0-9]+_(?<bind_port>[0-9]+))=(?<service_host>[^:]+):(?<service_port>[0-9]+)\s*$/
SSH_TUNNEL_REGEX = /^\s*(?<tunnel_name>SSH_((?<tunnel_type>REMOTE|LOCAL)_)?TUNNEL_[_A-Z0-9]+_(?<bind_port>[0-9]+))=(?<service_host>[^:]+):(?<service_port>[0-9]+)\[((?<ssh_user>[^@]+)@)?(?<ssh_host>[^:]+)(:(?<ssh_port>[0-9]+))?\]\s*$/

services = []

# Create SSH daemon service configurations
if ENV['START_SSH_DAEMON'] == 'yes'
  command = []
  command << `which sshd`.strip
  command << '-D'
  command += Array.new(ENV['SSH_DEBUG_LEVEL'].to_i) { '-d' }
  command += ['-f', '/etc/ssh/sshd_config']
  command += ['-h', ENV['SSH_HOST_KEY_FILE']]
  command += ['-o', 'AllowTcpForwarding=yes']
  command += ['-o', "AllowUsers=#{ENV['SSH_ALLOW_USERS'] || ENV['AMBASSADOR_USER']}"]
  command += ['-o', "AuthorizedKeysFile=#{ENV['SSH_AUTHORIZED_KEYS_FILE']}"]
  command += ['-o', 'ChallengeResponseAuthentication=no']
  command += ['-o', "ClientAliveInterval=#{ENV['SSH_CLIENT_ALIVE_INTERVAL'].to_i}"] if ENV['SSH_CLIENT_ALIVE_INTERVAL']
  command += ['-o', 'GatewayPorts=clientspecified']
  command += ['-o', "ListenAddress=#{ENV['TUNNEL_BIND_ADDRESS']}"]
  command += ['-o', 'PermitRootLogin=no'] unless ENV['AMBASSADOR_USER'] == 'root'
  command += ['-o', 'PermitTunnel=yes']
  command += ['-p', ENV['SSH_LISTEN_PORT']]
  services << { service_name: 'sshd.service', service_command: command.join(' ') }
end

# Create TCP tunnel service configurations
ENV.keys.map { |k| TCP_TUNNEL_REGEX.match("#{k}=#{ENV.fetch(k)}") }.compact.each do |match|
  attrs = Hash[match.names.zip(match.captures)].merge('bind_address' => ENV['TUNNEL_BIND_ADDRESS'])
  command = []
  command << `which socat`.strip
  command += Array.new(ENV['SOCAT_DEBUG_LEVEL'].to_i) { '-d' }
  command << "TCP-LISTEN:#{attrs['bind_port']},bind=#{attrs['bind_address']},fork"
  command << "TCP:#{attrs['service_host']}:#{attrs['service_port']},reuseaddr"
  services << { service_name: "#{attrs['tunnel_name'].downcase}.service", service_command: command.join(' ') }
end

# Create SSH tunnel service configurations
ENV.keys.map { |k| SSH_TUNNEL_REGEX.match("#{k}=#{ENV.fetch(k)}") }.compact.each do |match|
  attrs = Hash[match.names.zip(match.captures)].merge('bind_address' => ENV['TUNNEL_BIND_ADDRESS'])
  is_reverse = attrs['tunnel_type'] == 'REMOTE'
  command = []
  command += [`which sshpass`.strip, '-p', ENV['SSH_PASSWORD']] if ENV['SSH_PASSWORD']
  command += [`which autossh`.strip, '-M', '0', '-T', '-N']
  command += Array.new(ENV['SSH_DEBUG_LEVEL'].to_i) { '-v' }
  command += ['-o', 'StrictHostKeyChecking=no']
  command += ['-o', 'UserKnownHostsFile=/dev/null']
  command += ['-o', "ServerAliveInterval=#{ENV['SSH_SERVER_ALIVE_INTERVAL'].to_i}"] if ENV['SSH_SERVER_ALIVE_INTERVAL']
  command += ['-o', "Port=#{attrs['ssh_port'] || ENV['SSH_PORT']}"]
  command += ['-o', "User=#{attrs['ssh_user'] || ENV['AMBASSADOR_USER']}"]
  unless ENV['SSH_PASSWORD']
    command += ['-o', 'PasswordAuthentication=no']
    command += ['-o', "IdentityFile='#{ENV['SSH_IDENTITY_FILE'] || ENV['SSH_CLIENT_KEY_FILE'] || "#{ENV['HOME']}/.ssh/id_rsa"}'"]
  end
  command << (is_reverse ? '-R' : '-L')
  command += ["#{attrs['bind_address']}:#{attrs['bind_port']}:#{attrs['service_host']}:#{attrs['service_port']}", attrs['ssh_host']]
  services << { service_name: "#{attrs['tunnel_name'].downcase}.service", service_command: command.join(' ') }
end

class ErbBinding < OpenStruct
  def render(template)
    ERB.new(template).result(binding)
  end
end

# Write service configurations
services.each do |attrs|
  template_file = '/usr/share/chaperone/service.conf.erb'
  erb = ErbBinding.new(attrs).render(File.read(template_file))
  File.write(File.join(ENV['CHAPERONE_CONFIG_DIR'], "#{attrs[:service_name]}.conf"), erb)
end
