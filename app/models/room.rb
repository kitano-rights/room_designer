class Room < ApplicationRecord
  # 部屋の形（mm）。当面はこの六角形で固定し、エディターでの形状・サイズの編集は行わない
  # アイソメトリック表示（左右の壁＋床）の輪郭にあたる
  FIXED_CORNERS = [
    [ 2500, 400 ], [ 4600, 1200 ], [ 4600, 2400 ],
    [ 2500, 3200 ], [ 400, 2400 ], [ 400, 1200 ]
  ].freeze

  # アイソメトリック表示で奥行きを表す内側の線（[始点, 終点] の組）
  # 始点は壁と床が集まる部屋の奥の角。上端の頂点から壁の高さ（1200）だけ
  # 真下に置くことで、外周の左右の縦エッジと壁の高さが揃う
  FIXED_DEPTH_LINES = [
    [ [ 2500, 1600 ], [ 2500, 400 ] ],   # 壁と壁の縦の角
    [ [ 2500, 1600 ], [ 400, 2400 ] ],   # 左の壁と床の境目
    [ [ 2500, 1600 ], [ 4600, 2400 ] ]   # 右の壁と床の境目
  ].freeze

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
