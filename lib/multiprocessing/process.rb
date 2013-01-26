require File.expand_path(File.dirname(__FILE__) + '/processerror')

module MultiProcessing
  class Process

    attr_reader :pid

    def initialize *args
      raise ProcessError.new "mulst be called with a block" unless block_given?
      @pid = fork do
        yield *args
        exit
      end
    end

    def value
      th = ::Process.detach(@pid)
      th.value
    end

    def join timeout=nil
      th = ::Process.detach(@pid)
      th.join timeout
    end

    def kill signal
      ::Process.kill signal, @pid
    end

  end
end

if $0 == __FILE__
  include MultiProcessing

  p = MultiProcessing::Process.new("nyan") do |str|
    puts str
    sleep 1
  end
  p p
  p.join
end

