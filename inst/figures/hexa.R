library(hexSticker)
library(showtext)
library(magick)
library(viridis)
library(colorspace)

font_add_google("Lato", "lato")
showtext_auto()

dir <- "/Users/maxlindmark/Dropbox/max-work/R/stomachr/inst/figures/"

# ── Colour scheme ─────────────────────────────────────────────────────────────
fish_col   <- viridis::mako(1, begin = 1)
border_col <- viridis::mako(1, begin = 1)
fill_col   <- colorspace::darken(viridis::mako(1, begin = 0.62), amount = 0.35)

# Recolor + thicken fish
fish <- image_read(paste0(dir, "fish.png"))
fish <- image_convert(fish, "PNG")
fish <- image_transparent(fish, "white", fuzz = 10)
fish <- image_morphology(fish, "Dilate", "Diamond", iterations = 2) # thicken lines
fish <- image_colorize(fish, opacity = 90, color = fish_col)
fish <- image_fx(fish, expression = "a*0.6", channel = "alpha") # fish alpha
image_write(fish, paste0(dir, "fish_mako.png"))

sticker(
  paste0(dir, "fish_mako.png"),
  package  = "stomachr",
  p_size   = 34,
  p_y      = 1.4,
  p_family = "lato",
  p_color  = border_col,
  s_x      = 1,
  s_y      = 0.8,
  s_width  = 0.7,
  s_height = 0.7 * 1.15 / 1.1,
  h_fill   = fill_col,
  h_color  = border_col,
  h_size   = 2,
  dpi      = 600, # dpi < ~300 makes showtext render the package text oversized/clipped
  filename = paste0(dir, "stomachr.png")
)

sticker_img <- image_read(paste0(dir, "stomachr.png"))
sticker_w   <- image_info(sticker_img)$width
sticker_h   <- image_info(sticker_img)$height

db <- image_read(paste0(dir, "db2.png"))
db <- image_convert(db, "PNG")
db <- image_transparent(db, "white", fuzz = 10)
db <- image_colorize(db, opacity = 90, color = fish_col)
db <- image_fx(db, expression = "a*0.55", channel = "alpha") # db alpha
db <- image_scale(db, paste0(round(sticker_w * 1.1)))

final <- image_composite(sticker_img, db,
                         operator = "over",
                         offset   = paste0("+0+", round(sticker_h * 0.4)))

final <- image_trim(final)
image_write(final, paste0(dir, "stomachr.png"))
file.copy(paste0(dir, "stomachr.png"), "man/figures/logo.png", overwrite = TRUE)
