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

  # 家具画像の角度への丸め
  context ".normalize_image_angle" do
    should "回転角を画像が存在する90度刻みへ丸める" do
      assert_equal 0, Furniture.normalize_image_angle(0)
      assert_equal 90, Furniture.normalize_image_angle(45)
      assert_equal 90, Furniture.normalize_image_angle(90)
      assert_equal 180, Furniture.normalize_image_angle(170)
      assert_equal 0, Furniture.normalize_image_angle(315)
      assert_equal 270, Furniture.normalize_image_angle(-90)
    end
  end
end
