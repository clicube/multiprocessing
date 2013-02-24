require 'thread'
require File.expand_path(File.dirname(__FILE__) + '/mutex')
require File.expand_path(File.dirname(__FILE__) + '/semaphore')

module MultiProcessing

  class QueueError < StandardError; end

  ##
  #
  # This class provides a way to synchronize communication between process.
  #
  # Note that Queue uses 8 pipes ( 2 pipes, 2 Mutex, 1 Semaphore).
  #
  # @example
  #   require 'multiprocessing'
  #
  #   q = MultiProcessing::Queue.new
  #   fork do
  #     q.push :nyan
  #     q.push :wan
  #     q.close.join_thread
  #   end
  #   q.pop # => :nyan
  #   q.pop # => :wan
  #
  class Queue

    def initialize
      @count = Semaphore.new 0
      @write_mutex = Mutex.new
      @read_mutex = Mutex.new
      @len_pout, @len_pin = IO.pipe
      @data_pout, @data_pin = IO.pipe
      @enq_queue = ::Queue.new
      @queue_zero_cond = ::ConditionVariable.new
      @closed = false
    end

    ##
    #
    # Removes all objects from the queue
    #
    # @return [Queue] self
    #
    def clear
      begin
        loop do
          @read_mutex.synchronize do
            self.deq(true)
          end
        end
      rescue Errno::EAGAIN
      end
    end

    ##
    #
    # Returns true if the queue is empty.
    #
    # @return [Boolean]
    #
    def empty?
      length == 0
    end

    ##
    #
    # Returns number of items in the queue.
    #
    # @return [Fixnum]
    #
    def length
      return @count.value
    end
    alias :size :length
    alias :count :length

    ##
    #
    # Retrieves data from the queue.
    # If the queue is empty, the calling thread is suspended until data is pushed onto the queue.
    # If non_block is true, thread isn't suspended, and exception is raised.
    #
    # @param [Boolean] non_block
    # @return [Object]
    #
    def deq non_block=false
      data = ""
      @read_mutex.synchronize do
        unless non_block
          @count.wait
        else
          @count.trywait
        end

        buf = ""
        len = nil
        begin
          c = @len_pout.readpartial 1
          if c == "\n"
            len = buf.to_i
          else
            buf << c
          end
        end while !len

        begin
          buf = @data_pout.readpartial len
          len -= buf.bytesize
          data << buf
        end while len > 0
      end
      return Marshal.load(data)

    end
    alias :pop :deq
    alias :shift :deq

    ##
    #
    # Pushes object to the queue.
    # Raise QueueError if the queue is already closed.
    # Raise TypeError if the object passed cannot be dumped with Marshal.
    #
    # @param [Object] obj
    # @return [Queue] self
    # @raise [QueueError] the queue is already closed.
    # @raise [TypeError] object cannot be dumped with Marshal.
    # 
    def enq obj
      raise QueueError.new("already closed") if @closed
      unless(@enq_thread && @enq_thread.alive?)
        @enq_queue.clear
        @enq_thread = Thread.new &method(:enq_loop)
      end
      @enq_queue.enq(Marshal.dump(obj))
      Thread.pass
    end
    alias :push :enq
    alias :unshift :enq

    def enq_loop
      loop do
        data = @enq_queue.deq
        @write_mutex.synchronize do
          @count.post
          @len_pin.write data.length.to_s + "\n"
          @len_pin.flush
          @data_pin.write data
          @data_pin.flush
        end
        Thread.exit if @closed && @enq_queue.length == 0
      end
    end
    private :enq_loop

    ##
    #
    # Close the queue.
    # After closing, the queue cannot be pushed any object.
    # {#join_thread} can call only after closing the queue.
    #
    # @return [Queue] self
    #
    def close
      @closed = true
      self
    end

    ##
    #
    # Join the thread enqueueing.
    # This can call only after closing({#close}) queue.
    #
    # @return [Queue] self
    # @raise [QueueError] the queue is not closed.
    # 
    def join_thread
      raise QueueError.new("must be closed before join_thread") unless @closed
      if @enq_thread && @enq_thread.alive?
        @enq_thread.join
      end
      self
    end

  end
end

