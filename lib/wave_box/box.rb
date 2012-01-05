module WaveBox
  class Box
    attr_reader :expire, :max_size

    def initialize(options)
      @options = options
      @expire = options[:expire]
      @max_size = options[:max_size]
      @redis = options[:redis]
      @key = options[:key]
      @encode = options[:encode]
    end

    def push(value, time = Time.now)
      if @encode == false
        v = value
      else
        v = encode(value)
      end
      @redis.zadd(@key, time.to_i, v)

      truncate!
    end

    def size
      @redis.zcard @key
    end

    def after(time)
      items = @redis.zrangebyscore( @key, "#{time.to_i}", "+inf")

      if @encode == false
        items
      else
        items.map { |x| decode(x) }
      end
    end

    private

    # TODO: Current encode/decode solution sucks,
    # it create too much storage overhead
    def encode(str)
      "#{str}:#{Time.now.to_i}:#{rand.to_s.to_f}"
    end

    def decode(str)
      str.split(':')[0..-3].join(':')
    end

    def truncate!
      @redis.zremrangebyscore( @key, 0, (Time.now - @expire).to_f ) if @expire
      @redis.zremrangebyrank( @key, 0, -1*(@max_size + 1) ) if @max_size
    end
  end
end
