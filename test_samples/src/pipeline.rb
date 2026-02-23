class EventBus
  def initialize
    @listeners = Hash.new { |h, k| h[k] = [] }
  end

  def on(event, &block)
    @listeners[event] << block
    self
  end

  def emit(event, *args)
    @listeners[event].each { |cb| cb.call(*args) }
  end

  def off(event, &block)
    @listeners[event].delete(block)
  end

  def once(event, &block)
    wrapper = proc do |*args|
      block.call(*args)
      off(event, &wrapper)
    end
    on(event, &wrapper)
  end
end

class Pipeline
  def initialize
    @steps = []
  end

  def add_step(name, &block)
    @steps << { name: name, action: block }
    self
  end

  def execute(input)
    result = input
    @steps.each do |step|
      puts "Running step: #{step[:name]}"
      result = step[:action].call(result)
    end
    result
  end
end

# Usage
bus = EventBus.new
bus.on(:data) { |val| puts "Received: #{val}" }

pipeline = Pipeline.new
pipeline
  .add_step("double") { |x| x * 2 }
  .add_step("add_10") { |x| x + 10 }
  .add_step("to_string") { |x| "Result: #{x}" }

output = pipeline.execute(5)
puts output

bus.emit(:data, output)
