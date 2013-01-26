require File.expand_path(File.dirname(__FILE__) + '/mutex')
require File.expand_path(File.dirname(__FILE__) + '/conditionvariable')

module MultiProcessing
  class Semaphore

    def initialize count
      @count_pout, @count_pin = IO.pipe
      @count_pin.syswrite "1"*count
      #@count_pin.write "1"*count
      #@count_pin.flush
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
        #@count_pin.write "1"*n
        #@count_pin.flush
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
    end
    alias :lock :P
    alias :wait :P

    def tryP
      @mutex.synchronize do
        @count_pout.read_nonblock 1
      end
    end
    alias :trylock :tryP
    alias :trywait :tryP

    def V
      @mutex.synchronize do
        @count_pin.syswrite 1
        #@count_pin.write 1
        #@count_pin.flush
        @cond.signal
      end
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

if $0 == __FILE__
  s = MultiProcessing::Semaphore.new 1
  fork
  s.wait
  puts Process.pid
  sleep 1
  s.post
end
