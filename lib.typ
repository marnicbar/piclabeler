#import "@preview/cetz:0.5.2"


#let rebase-coord(
  coordinate,
  base,
) = {
  let coord-type = type(coordinate)
  if coord-type == str {
    base + "." + coordinate
  } else if coord-type == dictionary and "to" in coordinate {
    (
      ..coordinate,
      to: base + "." + coordinate.to,
    )
  } else {
    coordinate
  }
}

#let origin-grid(
  from,
  to,
  origin,
  stroke: luma(40%) + 0.5pt,
  origin-stroke: black + 1pt,
  halo-width: 0.25pt,
) = {
  import cetz.draw: content, get-ctx, line, rect

  let range-division(min, max, origin, step) = {
    let min-step = calc.ceil((min - origin) / step)
    let max-step = calc.floor((max - origin) / step)
    let steps = range(min-step, max-step + 1)
    let values = steps.map(k => origin + k * step)
    (steps: steps, values: values)
  }

  get-ctx(ctx => {
    let (
      _,
      (from-x, from-y, _),
      (to-x, to-y, _),
      (origin-x, origin-y, _),
    ) = cetz.coordinate.resolve(ctx, from, to, origin)

    let x-range = range-division(from-x, to-x, origin-x, 1)
    let y-range = range-division(from-y, to-y, origin-y, 1)

    let unit = ctx.length
    let pad = 3pt / unit

    // Max y-label width in CeTZ units
    let max-y-lw = y-range.steps.fold(0.0, (acc, val) => {
      let w = measure(text(str(val))).width / unit
      if w > acc { w } else { acc }
    })

    // x-label height in CeTZ units
    let x-lh = measure(text("0")).height / unit

    let y-col-w = max-y-lw + 2 * pad
    let x-row-h = x-lh + 2 * pad

    let halo-stroke = if halo-width != none { white + (2 * halo-width + stroke.thickness) } else { none }
    let origin-halo-stroke = if halo-width != none { white + (2 * halo-width + origin-stroke.thickness) } else { none }

    if halo-stroke != none {
      for (x, step) in x-range.values.zip(x-range.steps) {
        line((x, from-y), (x, to-y), stroke: if step == 0 { origin-halo-stroke } else { halo-stroke })
      }
      for (y, step) in y-range.values.zip(y-range.steps) {
        line((from-x, y), (to-x, y), stroke: if step == 0 { origin-halo-stroke } else { halo-stroke })
      }
    }

    for (x, step) in x-range.values.zip(x-range.steps) {
      line((x, from-y), (x, to-y), stroke: if step == 0 { origin-stroke } else { stroke })
    }
    for (y, step) in y-range.values.zip(y-range.steps) {
      line((from-x, y), (to-x, y), stroke: if step == 0 { origin-stroke } else { stroke })
    }

    // Semitransparent hollow-rectangle label background
    let bg = white.transparentize(40%)
    rect((from-x, from-y), (from-x + y-col-w, to-y), fill: bg, stroke: none)
    rect((to-x - y-col-w, from-y), (to-x, to-y), fill: bg, stroke: none)
    if from-x + y-col-w < to-x - y-col-w {
      rect((from-x + y-col-w, from-y), (to-x - y-col-w, from-y + x-row-h), fill: bg, stroke: none)
      rect((from-x + y-col-w, to-y - x-row-h), (to-x - y-col-w, to-y), fill: bg, stroke: none)
    }

    // x-axis labels — skip any that overlap the y-column strips
    for (x, val) in x-range.values.zip(x-range.steps) {
      let lw = measure(text(str(val))).width / unit
      if x - lw / 2 < from-x + y-col-w { continue }
      if x + lw / 2 > to-x - y-col-w { continue }
      content((x, from-y + x-row-h / 2), text(str(val)), anchor: "center")
      content((x, to-y - x-row-h / 2), text(str(val)), anchor: "center")
    }

    // y-axis labels — skip any that overflow the canvas
    for (y, val) in y-range.values.zip(y-range.steps) {
      let lh = measure(text(str(val))).height / unit
      if y - lh / 2 < from-y { continue }
      if y + lh / 2 > to-y  { continue }
      content((from-x + y-col-w - pad, y), text(str(val)), anchor: "east")
      content((to-x - pad, y), text(str(val)), anchor: "east")
    }
  })
}

#let max-length(img-len, default-img-len, max-block-len) = {
  let len
  if type(img-len) == type(auto) {
    len = calc.min(default-img-len, max-block-len)
  } else if type(img-len) == ratio {
    len = max-block-len * img-len
  } else {
    len = calc.min(img-len, max-block-len)
  }
  len
}

#let annotated-image(
  image,
  body,
  grid: auto,
  width: auto,
  height: auto,
  image_width: auto,
  image_height: auto,
  image_pos: (rel: (0, 0), to: "bounding_box.center"),
  image_anchor: "center",
  origin_pos: "image.center",
  n_cells: (x: auto, y: 10),
) = {
  block(
    clip: true,
    width: width,
    height: height,
    layout(size => context {
      assert(
        n_cells.values().filter(x => x == auto).len() == 1,
        message: "The grid division must be defined for exactly one dimension.",
      )

      // Use name with underscore to avoid collision with grid function from CeTZ
      let _grid = grid

      let img-raw-size = measure(image)
      let max-img-width = max-length(image_width, img-raw-size.width, size.width)
      let max-img-height = max-length(image_height, img-raw-size.height, size.height)

      let width-driven-img-scale = max-img-width / img-raw-size.width
      let height-driven-img-scale = max-img-height / img-raw-size.height

      let img
      // // Width constrained
      if width-driven-img-scale <= height-driven-img-scale {
        img = scale(
          reflow: true,
          width-driven-img-scale * 100%,
          image,
        )
      } // Height constrained
      else {
        img = scale(
          reflow: true,
          height-driven-img-scale * 100%,
          image,
        )
      }

      let len = if n_cells.x != auto {
        measure(img).width / n_cells.x
      } else {
        measure(img).height / n_cells.y
      }

      let eps = 0.001
      let bounding_box = (
        from: (-eps, -eps),
        to: (eps, eps),
      )
      if width != auto {
        bounding_box.from.at(0) = -size.width / 2
        bounding_box.to.at(0) = size.width / 2
      }
      if height != auto {
        bounding_box.from.at(1) = -size.height / 2
        bounding_box.to.at(1) = size.height / 2
      }

      cetz.canvas(
        length: len,
        {
          import cetz.draw: *

          group(name: "content", {
            rect(
              bounding_box.from,
              bounding_box.to,
              stroke: none,
              name: "bounding_box",
            )

            content(
              image_pos,
              anchor: image_anchor,
              name: "image",
              img,
            )

            group(ctx => {
              let (_, center, north_east) = cetz.coordinate.resolve(ctx, "image.center", "image.north-east")

              let delta = cetz.vector.sub(north_east, center)

              set-viewport(
                origin_pos,
                (rel: (1, 1), to: origin_pos),
              )

              body
            })
          })
          if _grid != none {
            origin-grid("content.south-west", "content.north-east", rebase-coord(origin_pos, "content"))
          }
        },
      )
    }),
  )
}
