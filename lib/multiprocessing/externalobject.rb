require File.expand_path(File.dirname(__FILE__) + '/mutex')
require File.expand_path(File.dirname(__FILE__) + '/queue')

module MultiProcessing
  class ExternalObject < BasicObject

    def initialize obj
      @call_queue = Queue.new
      @result_queue = Queue.new
      @mutex = Mutex.new
      @closed = false
      @pid = fork{|o| process_loop o }
    end

    def process_loop obj
      while true
        *args = @call_queue.deq
        result = nil
        begin
          result = obj.__send__(*args)
        rescue => e
          result = e
        end
        @result_queue.enq result
      end
    end
    private :process_loop

    def send name, *args
      @mutex.synchronize do
        raise ProcessError.new("already closed") if @closed
        @call_queue.enq [name, *args]
        return @result_queue.deq
      end
    end

    def close
      @mutex.synchronize do
        @closed = true
        begin
          Process.kill :TERM, @pid
        rescue
        end
      end
    end

    def method_missing *args
      self.send(*args)
    end

  end
end



if $0 == __FILE__
  obj = MultiProcessing::ExternalObject.new({})
  obj[:cat] = :nyan
  obj[:dog] = :wan
  p obj

  obj_proxy = MultiProcessing::ExternalObject.new(obj)
  obj_proxy[:human] = :nyan
  p obj_proxy

  obj_proxy.close
  obj.close
end

