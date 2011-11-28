require 'spec_helper'
require "mock_redis"

describe WaveBox::Generator do

  it "should raise an argument error if no redis config is given" do
    lambda do
      class A
        include WaveBox::Generator

        wave_generator :box_id => lambda { self.object_id }
      end
    end.must_raise ArgumentError
  end

  it "should raise an ArgumentError if no box_id config is given" do
    lambda do
      class A
        include WaveBox::Generator

        wave_generator :redis => MockRedis.new
      end
    end.must_raise ArgumentError
  end

  describe "A normal generator usage" do
    before do
      class User
        include WaveBox::Generator

        wave_generator :redis => MockRedis.new,
                       :expire => 60*10,
                       :max_size => 10,
                       # You have to specify a box id which
                       # is unique among all receiver
                       :id => lambda { self.object_id }
      end

      @user = User.new
    end

    it "should save the box id lambda and call it when needed" do
      @user.wave_outbox_id.must_equal @user.object_id
    end

    it "should have an outbox" do
      @user.wave_outbox.wont_be_nil
    end

    describe "Sending wave" do
      before do
        class Receiver
          include WaveBox::Receiver

          wave_receiver :redis => MockRedis.new,
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
        @user.generate @wave, :to => @receiver

        @user.wave_outbox.size.must_equal 1
        @user.wave_outbox.after(0)[0].must_equal @wave

        @receiver.wave_inbox.size.must_equal 1
        @receiver.wave_inbox.after(0)[0].must_equal @wave
      end

      it "should be able to send multiple waves to a receiver and record them
        in the outbox" do
        n = 10
        n.times do |i|
          @user.generate @wave, :to => @receiver

          @user.wave_outbox.size.must_equal i+1
          @receiver.wave_inbox.size.must_equal i+1
        end
      end

      it "should be able to save options in its outbox" do
        @user.generate @wave, :to => @receiver, :time => Time.now - 10000
        @user.wave_outbox.after(0).size.must_equal 0
      end

      it "should be able to save options in the receiver's inbox" do
        @user.generate @wave, :to => @receiver, :time => Time.now - 10000
        # This wave will be truncated
        @receiver.wave_inbox.after(0).size.must_equal 0
      end

      it "should have a helper to retrieve outbox after..." do
        @user.generated_after(0).must_equal @user.wave_outbox.after(0)
      end

    end

  end
end

