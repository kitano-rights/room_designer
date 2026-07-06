require "test_helper"

class RoomTest < ActiveSupport::TestCase
  # バリデーション
  context "validations" do
    should validate_presence_of(:name)
    should validate_presence_of(:corners)
  end
end
