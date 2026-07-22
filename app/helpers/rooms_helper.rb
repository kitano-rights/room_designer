module RoomsHelper
  # corners([[x, y], ...]) を SVG polygon の points 属性値へ変換する
  def svg_polygon_points(corners)
    corners.map { |x, y| "#{x},#{y}" }.join(" ")
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
