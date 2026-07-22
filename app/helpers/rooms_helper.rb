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

  # 家具の描画順。ラグなど床レベルのもの（layer: 0）を先に描いて他の家具の下に敷く
  # 同じレイヤー内では奥から描き、手前の家具を前面に重ねる
  def furnitures_in_draw_order(furnitures)
    furnitures.each_with_index.sort_by do |furniture, index|
      [ Furniture::KIND_SPECS[furniture.kind][:layer] || 1, furniture_front_y(furniture), index ]
    end.map(&:first)
  end

  # 奥行き比較に使う「家具の接地部の手前端」の y。中心（pos_y）同士だと背の高い家具ほど
  # 接地面が画像中心より下に写るぶん奥に判定されてしまうため、実測の front_offset で補正する
  def furniture_front_y(furniture)
    spec = Furniture::KIND_SPECS[furniture.kind]
    return furniture.pos_y + spec[:front_offset] if spec[:front_offset]

    # 矩形描画の家具は回転後の矩形の下端
    radian = furniture.rotation * Math::PI / 180
    furniture.pos_y + (Math.sin(radian).abs * spec[:width] + Math.cos(radian).abs * spec[:depth]) / 2.0
  end

  # 家具画像（4方向レンダリング）のうち、rotation に対応する角度の画像パスを返す
  def furniture_image_path(spec, rotation)
    angle = Furniture.normalize_image_angle(rotation)
    image_path("furniture/#{spec[:image]}_#{format('%03d', angle)}.png")
  end

  # エディターの JS へ渡す家具スペック。画像がある家具には角度ごとの画像 URL を添える
  def editor_kind_specs
    Furniture::KIND_SPECS.transform_values do |spec|
      next spec unless spec[:image]

      spec.merge(images: Furniture::IMAGE_ANGLES.index_with { |angle| furniture_image_path(spec, angle) })
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
