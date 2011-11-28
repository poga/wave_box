require 'mock_redis'
require 'spec_helper'

describe WaveBox::Box do
  describe "A box without limit" do
    before do
      @box = WaveBox::Box.new :redis => MockRedis.new,
                               :key => "test_key"
    end

    it "should save pushed item" do
      @box.push(1)

      @box.size.must_equal 1
    end

    it "should return pushed items based on a timestamp" do
      @box.push("foo")

      @box.after(0).size.must_equal 1
      @box.after(0)[0].must_equal "foo"
    end

    it "should able to handle two identical items in a single box" do
      @box.push("foo")
      @box.push("foo")

      @box.after(0).size.must_equal 2
      @box.after(0).each { |x| x.must_equal "foo" }
    end

    it "should not truncate any item" do
      100.times { @box.push "foo" }

      @box.size.must_equal 100

      @box.push "bar", Time.now - 10000
      @box.after(0)[0].must_equal "bar"
    end
  end

  before do
    @max_size = 10
    @expire = 10*60
    @box_with_limit = WaveBox::Box.new({
                                    :redis => MockRedis.new,
                                    :key => "test_key",
                                    :expire => @expire,
                                    :max_size => @max_size })
  end

  describe "A box with limit" do
    it "should know its limit" do
      @box_with_limit.max_size.must_equal @max_size
      @box_with_limit.expire.must_equal @expire
    end

    it "should truncate items over max size limit" do
      20.times { @box_with_limit.push("foo") }

      @box_with_limit.size.must_equal @max_size
    end

    it "should truncate items over expire time" do
      @box_with_limit.push "foo", Time.now - (@expire + 10)

      @box_with_limit.size.must_equal 0
    end
  end

end
