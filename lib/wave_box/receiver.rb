module WaveBox
  module Receiver

    def receive(wave, options = {})
      default_options = { :time => Time.now }
      options = default_options.merge(options)

      wave_inbox.push(wave, options[:time])
    end

    def received_after(time)
      wave_inbox.after(time)
    end

    module ClassMethods
      def wave_receiver(config)
        raise ArgumentError, "Missing redis config" unless config[:redis]
        raise ArgumentError, "Missing id lambda" unless config[:id]

        [:redis, :expire, :max_size].each do |c|
          define_method "wave_inbox_#{c}" do config[c] end
        end

        class_eval <<-RUBY
          def wave_inbox
            @wave_inbox ||= WaveBox::Box.new({
                                  :redis => wave_inbox_redis,
                                  :key => wave_inbox_key,
                                  :expire => wave_inbox_expire,
                                  :max_size => wave_inbox_max_size})
          end
        RUBY

        define_method "wave_inbox_id", config[:id]
      end
    end

    def self.included(host)
      host.extend ClassMethods
    end

    private

    def wave_inbox_key
      return "wave:box:in:#{wave_inbox_id}"
    end

  end
end
