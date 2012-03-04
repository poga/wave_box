require 'spec_helper'
require "mock_redis"

describe WaveBox::GenerateWave do
  it "should raise an ArgumentError if no wave name is given" do
    lambda do
      class A
        include WaveBox::GenerateWave

        can_generate_wave :id => :box_id,
                          :redis => MockRedis.new
      end
    end.must_raise ArgumentError
  end

  it "should raise an argument error if no redis config is given" do
    lambda do
      class A
        include WaveBox::GenerateWave

        can_generate_wave :id => :box_id,
                          :name => "message"
      end
    end.must_raise ArgumentError
  end

  it "should raise an ArgumentError if no box_id config is given" do
    lambda do
      class A
        include WaveBox::GenerateWave

        can_generate_wave :redis => MockRedis.new,
                          :name => "message"
      end
    end.must_raise ArgumentError
  end

  it "Can accept a symbol as redis parameter" do
    class Sender
      include WaveBox::GenerateWave

      can_generate_wave :name => "message",
                        :redis => :dynamic_instance,
                        :expire => 60*10,
                        :max_size => 10,
                        # You have to specify a box id which
                        # is unique among all receiver
                        :id => :box_id

      def dynamic_instance
        return MockRedis.new
      end

      def box_id
        object_id
      end
    end

    class Receiver
      include WaveBox::ReceiveWave

      can_receive_wave :name => "message",
                       :redis => :dynamic_instance,
                       :expire => 60*10,
                       :max_size => 10,
                       # You have to specify a box id which
                       # is unique among all receiver
                       :id => :box_id
      def dynamic_instance
        return MockRedis.new
      end

      def box_id
        object_id
      end
    end

    s = Sender.new
    r = Receiver.new

    s.message_outbox.wont_be_nil
    s.generate_message "foo", r

    s.generated_message_after(0).size.must_equal 1
    r.received_message_after(0).size.must_equal 1
  end

  describe "A normal generator usage" do
    before do
      class User
        include WaveBox::GenerateWave

        can_generate_wave :name => "message",
                          :redis => MockRedis.new,
                          :expire => 60*10,
                          :max_size => 10,
                          # You have to specify a box id which
                          # is unique among all receiver
                          :id => :box_id

      def box_id
        object_id
      end
      end

      @user = User.new
    end

    it "should have an outbox with name" do
      @user.message_outbox.wont_be_nil
    end

    it "should save the box id lambda and call it when needed" do
      @user.message_outbox_id.must_equal @user.object_id
    end

    describe "Sending wave" do
      before do
        class Receiver
          include WaveBox::ReceiveWave

          can_receive_wave :name => "message",
                           :redis => MockRedis.new,
                           :expire => 60*10,
                           :max_size => 10,
                           # You have to specify a box id which
                           # is unique among all receiver
                           :id => :box_id

          def box_id
            object_id
          end
        end
        @receiver = Receiver.new
        @wave = "foo"
      end

      it "should be able to send wave to a receiver" do
        @user.generate "message", @wave, @receiver

        @user.message_outbox.size.must_equal 1
        @user.message_outbox.after(0)[0].must_equal @wave

        @receiver.message_inbox.size.must_equal 1
        @receiver.message_inbox.after(0)[0].must_equal @wave
      end

      it "should be able to send multiple waves to a receiver and record them
        in the outbox" do
        n = 10
        n.times do |i|
          @user.generate "message", @wave, @receiver

          @user.message_outbox.size.must_equal i+1
          @receiver.message_inbox.size.must_equal i+1
        end
      end

      it "should be able to save options in its outbox" do
        @user.generate "message", @wave, @receiver, Time.now - 10000
        @user.message_outbox.after(0).size.must_equal 0
      end

      it "should be able to save options in the receiver's inbox" do
        @user.generate "message", @wave, @receiver, Time.now - 10000
        # This wave will be truncated
        @receiver.message_inbox.after(0).size.must_equal 0
      end

      it "should have a helper to retrieve outbox after..." do
        @user.generated_after("message", 0).must_equal @user.message_outbox.after(0)
      end

      it "can be customized to not save a backup in its outbox in a sepcify call" do
        @user.generate "message", @wave, @receiver, Time.now, :outbox => false

        @user.message_outbox.after(0).size.must_equal 0
      end

      it "should utilize method_missing to provide some much better api" do
        @user.generate_message @wave, @receiver

        @user.generated_message_after(0).size.must_equal 1

        @receiver.message_inbox.size.must_equal 1
        @receiver.message_inbox.after(0)[0].must_equal @wave
      end

      it "should implement method missing politely" do
        @user.respond_to?(:generate_message).must_equal true
        @user.respond_to?(:generated_message_after).must_equal true
      end
    end

  end

  describe "USAGE: can generate multiple waves in a single class" do
    before do
      class MultipleSender
        include WaveBox::GenerateWave

        can_generate_wave :name => "message",
                          :redis => MockRedis.new,
                          :expire => 60*10,
                          :max_size => 10,
                          # You have to specify a box id which
                          # is unique among all receiver
                          :id => :box_id

        can_generate_wave :name => "stone",
                          :redis => MockRedis.new,
                          :expire => 60*10,
                          :max_size => 10,
                          # You have to specify a box id which
                          # is unique among all receiver
                          :id => :box_id


        def box_id
          object_id
        end
      end

      class MultipleReceiver
        include WaveBox::ReceiveWave

        can_receive_wave :name => "message",
                         :redis => MockRedis.new,
                         :expire => 60*10,
                         :max_size => 10,
                         # You have to specify a box id which
                         # is unique among all receiver
                         :id => :box_id

        can_receive_wave :name => "stone",
                         :redis => MockRedis.new,
                         :expire => 60*10,
                         :max_size => 10,
                         # You have to specify a box id which
                         # is unique among all receiver
                         :id => :box_id


        def box_id
          object_id
        end
      end

      @sender = MultipleSender.new
      @receiver = MultipleReceiver.new
    end

    it "Should have multiple outbox" do
      @sender.message_outbox.wont_be_nil
      @sender.stone_outbox.wont_be_nil
    end

    it "Should have multiple outbox key" do
      @sender.message_outbox_key.wont_equal @sender.stone_outbox_key
    end

    it "Should be able to send multiple type of waves without 
        conflicting each other" do
      @sender.generate_message "foo", @receiver
      @sender.generated_message_after(0).size.must_equal 1
      @receiver.received_after("message", 0).size.must_equal 1

      @sender.generate_stone "bar", @receiver

      @sender.generated_message_after(0).size.must_equal 1
      @sender.generated_stone_after(0).size.must_equal 1

      @receiver.received_message_after(0).size.must_equal 1
      @receiver.received_stone_after(0).size.must_equal 1
    end
  end
end

