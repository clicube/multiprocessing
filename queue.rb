require 'thread'
require_relative 'semaphore'
require_relative 'mutex'

module MultiProcessing

  class QueueError < StandardError; end

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

    def empty?
      length == 0
    end

    def length
      return @count.value
    end
    alias :size :length
    alias :count :length

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

    def enq obj
      raise QueueError.new("Queue already closed") if @closed
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

    def close
      @closed = true
      self
    end

    def join_thread
      raise QueueError.new("must be closed before join_thread") unless @closed
      if @enq_thread && @enq_thread.alive?
        @enq_thread.join
      end
    end

  end
end

if __FILE__ == $0

  q = MultiProcessing::Queue.new

  q.push(0)
  sleep 1
  pid = fork
  if !pid
    q.push("111")
    q.push({:a=>"a",:b=>123})
    p q.pop
    exit(0)
  end
  p q.pop
  p q.pop
  Process.waitall

end