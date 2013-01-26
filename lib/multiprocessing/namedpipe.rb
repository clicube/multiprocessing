class IO

  def self.named_pipe(path, create=true)
    if !File.exist?(path)&& create
      system "mkfifo #{path}"
    end
    raise IOError.new("it is not named pipe") if File.ftype(path) != "fifo"
    pout = File.open(path, "r+")
    pin = File.open(path, "w+")
    return pout, pin
  end

end

if __FILE__ == $0
  pout, pin = IO.named_pipe("nyan")
  3.times do
    pin.puts :nyan
  end
  pin.flush
  3.times do
    puts pout.gets
  end
  File.delete "nyan"
end
