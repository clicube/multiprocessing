require File.expand_path(File.dirname(__FILE__) + '/mutex')
require File.expand_path(File.dirname(__FILE__) + '/conditionvariable')

module MultiProcessing
  class Semaphore

    def initialize count
      @count_pout, @count_pin = IO.pipe
      @count_pin.syswrite "1"*count
      @mutex = Mutex.new
      @cond = ConditionVariable.new
    end

    def count_nonsynchronize
      n = 0
      begin
        loop do
          @count_pout.read_nonblock 1
          n += 1
        end
      rescue Errno::EAGAIN
        @count_pin.syswrite "1"*n
      end
      return n
    end
    private :count_nonsynchronize

    def count
      @mutex.synchronize do
        count_nonsynchronize
      end
    end
    alias :value :count

    def P
      @mutex.synchronize do
        while count_nonsynchronize == 0
          @cond.wait(@mutex)
        end
        @count_pout.readpartial 1
      end
      return self
    end
    alias :lock :P
    alias :wait :P

    def try_P
      begin
        @mutex.synchronize do
          @count_pout.read_nonblock 1
        end
        return true
      rescue Errno::EAGAIN
        return false
      end
    end
    alias :try_lock :try_P
    alias :try_wait :try_P

    def V
      @mutex.synchronize do
        @count_pin.syswrite 1
        @cond.signal
      end
      return self
    end
    alias :signal :V
    alias :unlock :V
    alias :post :V

    def synchronize
      self.P
      begin
        yield
      ensure
        self.V
      end
    end

  end
end

