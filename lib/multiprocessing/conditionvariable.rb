require File.expand_path(File.dirname(__FILE__) + '/processerror')
require File.expand_path(File.dirname(__FILE__) + '/mutex')

module MultiProcessing
  class ConditionVariable

    def initialize
      @waiting_pout,@waiting_pin = IO.pipe
      @signal_pout,@signal_pin = IO.pipe
    end

    def broadcast
      n = 0
      while(signal)
        n += 1
      end
      return n
    end

    def signal
      begin
        @waiting_pout.read_nonblock 1
        @signal_pin.syswrite 1
        #@signal_pin.write 1
        #@signal_pin.flush
        return true
      rescue Errno::EAGAIN
        return nil
      end
    end

    def wait(mutex)
      raise MultiProcessing::ProcessError.new("mutex must be instance of MultiProcessing::Mutex") if mutex.class != MultiProcessing::Mutex
      @waiting_pin.syswrite 1
      #@waiting_pin.write 1
      #@waiting_pin.flush
      mutex.unlock
      @signal_pout.readpartial 1
      mutex.lock
      self
    end

  end
end

if __FILE__ == $0

  m = MultiProcessing::Mutex.new
  cond = MultiProcessing::ConditionVariable.new
  fork do
    m.synchronize do
      sleep 1
      puts "waiting p1"
      cond.wait(m)
      puts "restarted p1"
      sleep 1
      puts "end p1"
    end
  end
  fork do
    m.synchronize do
      sleep 1
      puts "waiting p2"
      cond.wait(m)
      puts "restarted p2"
      sleep 1
      puts "end p2"
    end
  end
  fork do
    m.synchronize do
      sleep 1
      puts "waiting p3"
      cond.wait(m)
      puts "restarted p3"
      sleep 1
      puts "end p3"
    end
  end
  sleep 5
  puts "cond signaling"
  cond.signal
  sleep 3
  puts "cond broadcasting"
  cond.broadcast
  Process.waitall
end

