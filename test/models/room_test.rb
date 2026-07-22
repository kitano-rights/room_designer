require "test_helper"

class RoomTest < ActiveSupport::TestCase
  # 関連
  context "associations" do
    should have_many(:furnitures).dependent(:destroy)
  end

  # バリデーション
  context "validations" do
    should validate_presence_of(:name)

    # corners は空配列も許容する（nil のみ不可）
    should "allow empty array for corners" do
      room = Room.new(name: "テスト", corners: [])
      assert room.valid?
    end

    # 新規作成時は固定形状で開始し、俯瞰画面で部屋が表示される
    should "default corners to the fixed shape" do
      assert_equal Room::FIXED_CORNERS, Room.new.corners
    end

    should "not allow nil for corners" do
      room = Room.new(name: "テスト", corners: nil)
      assert_not room.valid?
      assert room.errors.of_kind?(:corners, :blank)
    end
  end
end
