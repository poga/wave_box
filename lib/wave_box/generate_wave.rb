module WaveBox
  module GenerateWave

    def generate(wave, options = {})
      default_options = { :time => Time.now }
      options = default_options.merge(options)

      wave_outbox.push wave, options[:time]

      if options[:to].respond_to? :each
        options[:to].each do |receiver|
          receiver.receive(wave, options.reject { |k,v| k == :to })
        end
      else
        options[:to].receive(wave, options.reject { |k,v| k == :to })
      end
    end

    def generated_after(time)
      wave_outbox.after(time)
    end

    module ClassMethods
      def generate_wave(config)
        raise ArgumentError, "Missing redis config" unless config[:redis]
        raise ArgumentError, "Missing id lambda" unless config[:id]

        [:redis, :expire, :max_size].each do |c|
          define_method "wave_outbox_#{c}" do config[c] end
        end

        class_eval <<-RUBY
          def wave_outbox
            @wave_outbox ||= WaveBox::Box.new({
                                  :redis => wave_outbox_redis,
                                  :key => wave_outbox_key,
                                  :expire => wave_outbox_expire,
                                  :max_size => wave_outbox_max_size})
          end
        RUBY

        define_method "wave_outbox_id", config[:id]
      end
    end

    def self.included(host)
      host.extend ClassMethods
    end

    private

    def wave_outbox_key
      return "wave:box:out:#{wave_outbox_id}"
    end
  end
end
