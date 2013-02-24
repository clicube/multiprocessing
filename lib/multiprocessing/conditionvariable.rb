require File.expand_path(File.dirname(__FILE__) + '/processerror')
require File.expand_path(File.dirname(__FILE__) + '/mutex')

module MultiProcessing

  ##
  #
  # Process version of ConditionVariable
  # This can be used like ::ConditionVariable in Ruby standard library.
  #
  # Note that ConditionVariable uses 2 pipes.
  #
  # @example
  #   m = MultiProcessing::Mutex.new
  #   cond = MultiProcessing::ConditionVariable.new
  #   3.times do
  #     fork do
  #       m.synchronize do
  #         puts "waiting pid:#{Process.pid}"
  #         cond.wait(m)
  #         puts "restarted pid:#{Process.pid}"
  #       end
  #     end
  #   end
  #   sleep 0.1 # => 3 processes get waiting a signal
  #   cond.signal # => One process restarts
  #   cond.broadcast # => Remaining 2 process restart
  #   Process.waitall
  #
  class ConditionVariable

    def initialize
      @waiting_pout,@waiting_pin = IO.pipe
      @signal_pout,@signal_pin = IO.pipe
    end

    ##
    #
    # Wakes up all threads waiting for this lock.
    #
    # @return [Fixnum] Number of threads waked up
    #
    def broadcast
      n = 0
      while(signal)
        n += 1
      end
      return n
    end

    ##
    #
    # Wakes up one of threads waiting for this lock.
    #
    # @return [Boolean] Returns true if wakes up. Returns false if no threads were waiting.
    #
    def signal
      begin
        @waiting_pout.read_nonblock 1
        @signal_pin.syswrite 1
        return true
      rescue Errno::EAGAIN
        return false
      end
    end

    ##
    #
    # Releases the lock held in mutex and waits, reacquires the lock on wakeup.
    #
    # @param [Mutex] mutex An instance of MultiProcessing::Mutex. It must be locked.
    # @return [ConditionVariable] itself
    # @note Do not pass an instance of ::Mutex. Pass an instance of MultiProcessing::Mutex.
    #
    # @raise [TypeError]
    # @raise [ArgumentError]
    #
    def wait(mutex)
      raise TypeError.new("mutex must be instance of MultiProcessing::Mutex") if mutex.class != MultiProcessing::Mutex
      raise ArgumentError.new("mutex must be locked") unless mutex.locked?
      @waiting_pin.syswrite 1
      mutex.unlock
      @signal_pout.readpartial 1
      mutex.lock
      self
    end

  end
end

