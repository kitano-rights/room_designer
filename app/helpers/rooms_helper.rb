module RoomsHelper
  # corners([[x, y], ...]) を SVG polygon の points 属性値へ変換する
  def svg_polygon_points(corners)
    corners.map { |x, y| "#{x},#{y}" }.join(" ")
  end

  # wall_color の値（カラーコード or テクスチャキー）を SVG の fill 値へ変換する
  # side は "left" / "right"（壁ごとに傾けたパターンを使い分ける）
  def wall_fill(value, side)
    value.start_with?("#") ? value : "url(#wall-#{side}-#{value})"
  end

  # floor_color の値（カラーコード or テクスチャキー）を SVG の fill 値へ変換する
  def floor_fill(value)
    value.start_with?("#") ? value : "url(#floor-#{value})"
  end

  # 壁紙の選択肢（[表示名, 保存値, スウォッチの style] の配列）。色に加えテクスチャも選べる
  def wall_swatches
    color_swatches + texture_swatches(Room::WALL_TEXTURES)
  end

  # フローリングの選択肢
  def floor_swatches
    color_swatches + texture_swatches(Room::FLOOR_TEXTURES)
  end

  def color_swatches
    Room::COLOR_PALETTE.map { |name, color| [ name, color, "background-color: #{color}" ] }
  end

  def texture_swatches(textures)
    textures.map do |name, key|
      [ name, key, "background-image: url('#{image_path("textures/#{key}.png")}'); background-size: cover" ]
    end
  end

  # 部屋の形全体が余白付きで収まる viewBox を返す
  def room_view_box(corners, padding: 400)
    xs = corners.map(&:first)
    ys = corners.map(&:last)
    min_x = xs.min - padding
    min_y = ys.min - padding
    "#{min_x} #{min_y} #{xs.max + padding - min_x} #{ys.max + padding - min_y}"
  end
end
