require 'spec_helper'
require "mock_redis"

describe WaveBox::GenerateWave do
  it "should raise an ArgumentError if no wave name is given" do
    lambda do
      class A
        include WaveBox::GenerateWave

        generate_wave :id => lambda { self.object_id },
                      :redis => MockRedis.new
      end
    end.must_raise ArgumentError
  end

  it "should raise an argument error if no redis config is given" do
    lambda do
      class A
        include WaveBox::GenerateWave

        generate_wave :id => lambda { self.object_id },
                      :name => "message"
      end
    end.must_raise ArgumentError
  end

  it "should raise an ArgumentError if no box_id config is given" do
    lambda do
      class A
        include WaveBox::GenerateWave

        generate_wave :redis => MockRedis.new,
                      :name => "message"
      end
    end.must_raise ArgumentError
  end

  describe "A normal generator usage" do
    before do
      class User
        include WaveBox::GenerateWave

        generate_wave :name => "message",
                      :redis => MockRedis.new,
                      :expire => 60*10,
                      :max_size => 10,
                      # You have to specify a box id which
                      # is unique among all receiver
                      :id => lambda { self.object_id }
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

          receive_wave :name => "message",
                       :redis => MockRedis.new,
                       :expire => 60*10,
                       :max_size => 10,
                       # You have to specify a box id which
                       # is unique among all receiver
                       :id => lambda { self.object_id }
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

      it "should utilize method_missing to provide some much better api" do
        @user.generate_message @wave, @receiver

        @user.generated_message_after(0).size.must_equal 1

        @receiver.message_inbox.size.must_equal 1
        @receiver.message_inbox.after(0)[0].must_equal @wave
      end

      it "should respond to method missing helpers" do
        @user.respond_to?(:generate_message).must_equal true
        @user.respond_to?(:generated_message_after).must_equal true
      end
    end

  end
end

