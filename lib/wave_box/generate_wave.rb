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
      def generate_wave(config)
        raise ArgumentError, "Missing redis" unless config[:redis]
        raise ArgumentError, "Missing id lambda" unless config[:id]
        raise ArgumentError, "Missing wave name" unless config[:name]

        [:redis, :expire, :max_size].each do |c|
          define_method "#{config[:name]}_outbox_#{c}" do config[c] end
        end

        define_method "#{config[:name]}_outbox_key" do "wave:#{config[:name]}:outbox:#{send("#{config[:name]}_outbox_id")}" end

        class_eval <<-RUBY
          def #{config[:name]}_outbox
            @wave_outbox ||= WaveBox::Box.new({
                                :redis => #{config[:name]}_outbox_redis,
                                :key => #{config[:name]}_outbox_key,
                                :expire => #{config[:name]}_outbox_expire,
                                :max_size => #{config[:name]}_outbox_max_size})
          end
        RUBY

        define_method "#{config[:name]}_outbox_id", config[:id]
      end
    end

    def self.included(host)
      host.extend ClassMethods
    end

  end
end
