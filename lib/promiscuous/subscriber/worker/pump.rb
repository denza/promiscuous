class Promiscuous::Subscriber::Worker::Pump
  def initialize(root)
    @root = root
    # late include of CelluloidSubscriber because the class is resolved
    # at runtime since we can have different backends.
    extend Promiscuous::AMQP::Subscriber
  end

  def connect
    options = {}
    options[:bindings] = {}
    # We need to subscribe to everything to keep up with the version tracking
    Promiscuous::Config.subscriber_exchanges.each do |exchange|
      options[:bindings][exchange] = ['*']
    end

    subscribe(options, &method(:on_message))
  end

  def on_message(metadata, payload)
    msg = Promiscuous::Subscriber::Message.new(payload, :metadata => metadata, :root_worker => @root)
    @root.runner.messages_to_process << msg
  rescue Exception => e
    Promiscuous.warn "[receive] cannot process message: #{e}\n#{e.backtrace.join("\n")}"
    Promiscuous::Config.error_notifier.call(e)
  end
end
