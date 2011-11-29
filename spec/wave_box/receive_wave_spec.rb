require "spec_helper"
require 'mock_redis'

describe WaveBox::ReceiveWave do

  it "should raise an argument error if no redis config is given" do
    lambda do
      class A
        include WaveBox::ReceiveWave

        receive_wave :id => lambda { self.object_id }
      end
    end.must_raise ArgumentError
  end

  it "should raise an ArgumentError if no box_id config is given" do
    lambda do
      class A
        include WaveBox::ReceiveWave

        receive_wave :redis => MockRedis.new
      end
    end.must_raise ArgumentError
  end

  describe "A normal receiver usage" do
    before do
      class User
        include WaveBox::ReceiveWave

        receive_wave :redis => MockRedis.new,
                     :expire => 60*10,
                     :max_size => 10,
                     # You have to specify a box id which
                     # is unique among all receiver
                     :id => lambda { self.object_id }
      end

      @user = User.new
      @wave = "foo"
    end

    it "should save the box id lambda and call it when needed" do
      @user.wave_inbox_id.must_equal @user.object_id
    end

    it "should have an inbox" do
      @user.wave_inbox.wont_be_nil
    end

    it "should be able to receive wave and save it to its inbox" do
      @user.receive(@wave)

      @user.wave_inbox.size.must_equal 1
      @user.wave_inbox.after(0)[0].must_equal @wave
    end

    it "should have a helper to retrieve inbox after..." do
      @user.received_after(0).must_equal @user.wave_inbox.after(0)
    end
  end
end
