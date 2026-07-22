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

  # アイソメトリック表示の壁（左・右）と床の面。FIXED_CORNERS を奥の角（2500, 1600）で分割したもの
  FIXED_WALL_POLYGONS = [
    [ [ 400, 1200 ], [ 2500, 400 ], [ 2500, 1600 ], [ 400, 2400 ] ],    # 左の壁
    [ [ 2500, 400 ], [ 4600, 1200 ], [ 4600, 2400 ], [ 2500, 1600 ] ]   # 右の壁
  ].freeze
  FIXED_FLOOR_POLYGON = [
    [ 2500, 1600 ], [ 4600, 2400 ], [ 2500, 3200 ], [ 400, 2400 ]
  ].freeze

  # 巾木（壁と床の際に付ける帯）。壁の下端の辺を高さぶん真上へオフセットした平行四辺形
  # この投影では壁が垂直に立っているため、y を引くだけで壁面上の帯になる
  FIXED_BASEBOARD_HEIGHT = 100
  FIXED_BASEBOARD_POLYGONS = [
    [ [ 2500, 1500 ], [ 400, 2300 ], [ 400, 2400 ], [ 2500, 1600 ] ],   # 左の壁
    [ [ 2500, 1500 ], [ 4600, 2300 ], [ 4600, 2400 ], [ 2500, 1600 ] ]  # 右の壁
  ].freeze

  # 壁紙・フローリングで選べる色の候補（表示名 => カラーコード）
  COLOR_PALETTE = {
    "白" => "#ffffff"
  }.freeze

  # 壁紙・フローリングのテクスチャ候補（表示名 => 保存キー）
  # 画像は app/assets/images/textures/<キー>.png に置き、wall_color / floor_color にキーをそのまま保存する
  # （値が「#」始まりなら色、それ以外はテクスチャキーとして描画側で判定する）
  WALL_TEXTURES = {
    "織物（白）" => "wallpaper_fabric_white"
  }.freeze
  FLOOR_TEXTURES = {
    "木目（ナチュラル）" => "flooring_wood_natural"
  }.freeze

  # 関連
  has_many :furnitures, dependent: :destroy

  # バリデーション
  validates :name, presence: true
  validates :wall_color, inclusion: { in: COLOR_PALETTE.values + WALL_TEXTURES.values }
  validates :floor_color, inclusion: { in: COLOR_PALETTE.values + FLOOR_TEXTURES.values }
  # corners は新規作成時に空配列で開始するため nil のみ不可とする
  # （presence だと [] が invalid、exclusion だと空配列が常に invalid になるためカスタム検証）
  validate :corners_must_not_be_nil

  private

  def corners_must_not_be_nil
    errors.add(:corners, :blank) if corners.nil?
  end
end
