require "test_helper"
require "fluent/plugin/out_kubernetes_remote_syslog"

class RemoteSyslogOutputTest < MiniTest::Unit::TestCase
  def setup
    Fluent::Test.setup
  end

  def create_driver(conf = CONFIG, tag = "test.kubernetes_remote_syslog")
    Fluent::Test::OutputTestDriver.new(Fluent::RemoteSyslogOutput, tag) {}.configure(conf)
  end

  def test_configure
    d = create_driver %[
      type kubernetes_remote_syslog
      hostname foo.com
      host example.com
      protocol udp
      port 5566
      severity debug
      tag minitest
    ]

    d.run do
      d.emit(message: "foo")
    end

    loggers = d.instance.instance_variable_get(:@loggers)
    refute_empty loggers

    logger = loggers.values.first

    assert_equal "example.com", logger.instance_variable_get(:@remote_hostname)
    assert_equal 5566, logger.instance_variable_get(:@remote_port)
    assert_instance_of UDPSocket, logger.instance_variable_get(:@socket)

    p = logger.instance_variable_get(:@packet)
    assert_equal 1, p.facility
    assert_equal "minitest", p.tag
    assert_equal 7, p.severity
  end

  def test_configure_tcp
    @tcp_server = TCPServer.open('127.0.0.1', 0)
    @tcp_server_port = @tcp_server.addr[1]

    @tcp_server_wait_thread = Thread.start do
      @tcp_server.accept
    end

    d = create_driver %[
      type kubernetes_remote_syslog
      hostname localhost
      host 127.0.0.1
      protocol tcp
      port #{@tcp_server_port}
      severity debug
      tag minitest
      tls false
    ]

    d.run do
      d.emit(message: "foo")
    end

    loggers = d.instance.instance_variable_get(:@loggers)
    logger = loggers.values.first

    assert_equal "127.0.0.1", logger.instance_variable_get(:@remote_hostname)
    assert_equal @tcp_server_port, logger.instance_variable_get(:@remote_port)
    assert_instance_of TCPSocket, logger.instance_variable_get(:@socket)
    assert_equal false, logger.instance_variable_get(:@tls)

    p = logger.instance_variable_get(:@packet)
    assert_equal 1, p.facility
    assert_equal "minitest", p.tag
    assert_equal 7, p.severity

    @tcp_server.close
  end

  def test_rewrite_tag
    d = create_driver %[
      type kubernetes_remote_syslog
      hostname foo.com
      host example.com
      protocol udp
      port 5566
      severity debug
      tag new.${tag_parts[1]}
    ]

    d.run do
      d.emit(message: "foo")
    end

    loggers = d.instance.instance_variable_get(:@loggers)
    logger = loggers.values.first

    p = logger.instance_variable_get(:@packet)
    assert_equal "new.kubernetes_remote_syslog", p.tag
  end
end
