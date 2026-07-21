class Room < ApplicationRecord
  # 関連
  has_many :furnitures, dependent: :destroy

  # バリデーション
  validates :name, presence: true
  # corners は新規作成時に空配列で開始するため nil のみ不可とする
  # （presence だと [] が invalid、exclusion だと空配列が常に invalid になるためカスタム検証）
  validate :corners_must_not_be_nil

  private

  def corners_must_not_be_nil
    errors.add(:corners, :blank) if corners.nil?
  end
end
