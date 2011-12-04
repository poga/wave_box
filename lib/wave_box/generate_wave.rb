module WaveBox
  module GenerateWave
    def method_missing(method, *args, &block)
      if method.to_s =~ /generated_(\w+)_after/
        generated_after( $1, *args )
      elsif method.to_s =~ /generate_(\w+)/
        generate( $1, *args)
      else
        super
      end
    end

    # method missing with good manner
    def respond_to_missing?(method, *)
      (method =~ /generated_(\w+)_after/) || (method =~ /generate_(\w+)/) || super
    end

    def generate(name, wave, receiver, time = Time.now)
      send("#{name}_outbox").push wave, time

      if receiver.respond_to? :each
        receiver.each do |rec|
          rec.receive(name, wave, time)
        end
      else
        receiver.receive(name, wave, time)
      end
    end

    def generated_after(name, time)
      send("#{name}_outbox").after(time)
    end

    module ClassMethods
      def can_generate_wave(config)
        raise ArgumentError, "Missing redis" unless config[:redis]
        raise ArgumentError, "Missing id lambda" unless config[:id]
        raise ArgumentError, "Missing wave name" unless config[:name]

        name = config[:name]
        [:redis, :expire, :max_size, :encode].each do |c|
          define_method "#{name}_outbox_#{c}" do config[c] end
        end

        if config[:redis].is_a? Symbol
          class_eval <<-RUBY
            def #{name}_outbox_redis_instance
              send( "#{config[:redis]}" )
            end
          RUBY
        else
          define_method "#{name}_outbox_redis_instance" do config[:redis] end
        end

        if config[:id].is_a? Symbol
          class_eval <<-RUBY
            def #{name}_outbox_id
              send("#{config[:id]}")
            end
          RUBY
        else
          define_method "#{name}_outbox_id" do config[:redis] end
        end

        define_method "#{name}_outbox_key" do "wave:#{name}:outbox:#{send("#{name}_outbox_id")}" end

        class_eval <<-RUBY
          def #{name}_outbox
            @#{name}_outbox ||= WaveBox::Box.new({
                                :encode => #{name}_outbox_encode,
                                :redis => #{name}_outbox_redis_instance,
                                :key => #{name}_outbox_key,
                                :expire => #{name}_outbox_expire,
                                :max_size => #{name}_outbox_max_size})
          end
        RUBY

      end
    end

    def self.included(host)
      host.extend ClassMethods
    end

  end
end
