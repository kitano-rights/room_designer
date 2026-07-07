require "test_helper"

class FurnitureTest < ActiveSupport::TestCase
  # 関連
  context :associations do
    should belong_to(:room)
  end

  # バリデーション
  context "validations" do
    should validate_presence_of(:kind)
    should validate_presence_of(:pos_x)
    should validate_presence_of(:pos_y)
    should validate_presence_of(:rotation)
  end
end
