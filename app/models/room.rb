class Room < ApplicationRecord
  # 関連
  has_many :furnitures, dependent: :destroy

  # バリデーション
  validates :name, presence: true
  validates :corners, presence: true
end
