require_relative 'semaphore'

module MultiProcessing
  class Mutex < Semaphore
    def initialize name = nil
      if name
        super name, Fcntl::O_CREAT, File::Stat::S_IRUSR|S_IWUSR, 1
      else
        super 1
      end
    end
  end
end

