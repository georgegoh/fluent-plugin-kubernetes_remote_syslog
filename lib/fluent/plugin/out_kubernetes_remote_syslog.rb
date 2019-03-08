require "fluent/mixin/config_placeholders"
require "fluent/mixin/plaintextformatter"
require 'fluent/mixin/rewrite_tag_name'

module Fluent
  class RemoteSyslogOutput < Fluent::Output
    Fluent::Plugin.register_output("kubernetes_remote_syslog", self)

    config_param :hostname, :string, :default => ""

    include Fluent::Mixin::PlainTextFormatter
    include Fluent::Mixin::ConfigPlaceholders
    include Fluent::HandleTagNameMixin
    include Fluent::Mixin::RewriteTagName

    config_param :host,     :string
    config_param :port,     :integer, :default => 514
    config_param :protocol, :string,  :default => 'udp'
    config_param :tls,      :boolean, :default => false
    config_param :ca_file,  :string,  :default => ''

    config_param :facility,     :string,  :default => "user"
    config_param :severity,     :string,  :default => "notice"
    config_param :tag,          :string,  :default => "fluentd"
    config_param :packet_size,  :integer, :default => 1024

    def initialize
      super
      require "remote_syslog_sender"
      @loggers = {}
    end

    def shutdown
      super
      @loggers.values.each(&:close)
    end

    def emit(tag, es, chain)
      chain.next
      es.each do |time, record|
        record.each_pair do |k, v|
          if v.is_a?(String)
            v.force_encoding("utf-8")
          end
        end

        tag = rewrite_tag!(tag.dup)
        if @protocol.downcase == 'tcp'
          @loggers[tag] ||= RemoteSyslogSender::TcpSender.new(@host,
            @port,
            tls: @tls,
            ca_file: @ca_file,
            facility: @facility,
            severity: @severity,
            packet_size: @packet_size,
            program: tag,
            local_hostname: record['kubernetes_host'])
        else
          @loggers[tag] ||= RemoteSyslogSender::UdpSender.new(@host,
            @port,
            facility: @facility,
            severity: @severity,
            packet_size: @packet_size,
            program: tag,
            local_hostname: record['kubernetes_host'])
        end


        @loggers[tag].transmit format(tag, time, record)
      end
    end
  end
end
