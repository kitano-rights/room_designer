class Room < ApplicationRecord
  # バリデーション
  validates :name, presence: true
  validates :corners, presence: true
end
