require "test_helper"

class RoomTest < ActiveSupport::TestCase
  # バリデーション
  validates :name, presence: true
  validates :corners, presence: true
end
