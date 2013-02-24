require File.expand_path(File.dirname(__FILE__) + '/mutex')
require File.expand_path(File.dirname(__FILE__) + '/conditionvariable')

module MultiProcessing

  ##
  #
  # Like Mutex but can manage multiple resources.
  #
  # Note that Semaphore uses 4 pipes( 1 pipe, 1 Mutex, 1 ConditionVariable).
  #
  # @example
  #   require 'multiprocessing'
  #   
  #   s = MultiProcessing::Semaphore.new 2
  #   3.times do
  #     fork do
  #       s.synchronize do
  #         puts "pid: #{Process.pid}"
  #         sleep 1
  #       end
  #     end
  #   end
  #   Process.waitall
  #   # => 2 processes prints its pid immediately
  #   #    but the other does late.
  #
  class Semaphore

    ##
    #
    # A new instance of Semaphore
    #
    # @param [Fixnum] count is initial number of resource
    #
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

    ##
    #
    # Returns current number of resources.
    #
    # @return [Fixnum]
    #
    def count
      @mutex.synchronize do
        count_nonsynchronize
      end
    end
    alias :value :count

    ##
    #
    # Attempts to get the resource and wait if it isn't available.
    #
    # @return [Semaphore] self
    #
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

    ##
    #
    # Attempts to get the resource and returns immediately
    # Returns true if the resource granted.
    #
    # @return [Boolean]
    #
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

    ##
    #
    # Releases the resource.
    #
    # @return [Semaphore] self
    #
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

    ##
    #
    # Obtains a resource, runs the block, and releases the resource when the block completes.
    #
    # @return [Object] returned value of the block
    #
    def synchronize
      self.P
      begin
        ret = yield
      ensure
        self.V
      end
      ret
    end

  end
end

