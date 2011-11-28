module WaveBox
  class Box
    attr_reader :expire, :max_size

    def initialize(options)
      @options = options
      @expire = options[:expire]
      @max_size = options[:max_size]
      @redis = options[:redis]
      @key = options[:key]
    end

    def push(value, time = Time.now)
      @redis.zadd(@key, time.to_i, encode(value))

      truncate!
    end

    def size
      @redis.zcard @key
    end

    def after(time)
      @redis.zrangebyscore( @key, "(#{time.to_i}", "+inf")
            .map { |x| decode(x) }
    end

    private

    # TODO: Current encode/decode solution sucks
    def encode(str)
      "#{str}:#{Time.now.to_i}:#{rand.to_s.to_f}"
    end

    def decode(str)
      str.split(':')[0..-3].join(':')
    end

    def truncate!
      @redis.zremrangebyscore( @key, 0, Time.now - @expire ) if @expire
      @redis.zremrangebyrank( @key, 0, -1*(@max_size + 1) ) if @max_size
    end
  end
end
