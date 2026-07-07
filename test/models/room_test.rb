require "test_helper"

class RoomTest < ActiveSupport::TestCase
  # 関連
  context "associations" do
    should have_many(:furnitures).dependent(:destroy)
  end

  # バリデーション
  context "validations" do
    should validate_presence_of(:name)
    should validate_presence_of(:corners)
  end
end
