library(hexSticker)
library(showtext)
library(magick)

font_add_google("Lato", "lato")
showtext_auto()

dir <- "/Users/maxlindmark/Dropbox/max-work/R/stomachr/inst/figures/"

# Recolor fish
# Recolor fish
fish <- image_read(paste0(dir, "fish.png"))
fish <- image_convert(fish, "PNG")
fish <- image_transparent(fish, "white", fuzz = 10)
fish <- image_colorize(fish, opacity = 90, color = viridis::mako(1, begin = 1)) # fish color
fish <- image_fx(fish, expression = "a*0.6", channel = "alpha") # fish alpha
image_write(fish, paste0(dir, "fish_mako.png"))

sticker(
  paste0(dir, "fish_mako.png"),
  package  = "stomachr",
  p_size   = 60,
  p_y      = 1.4,
  p_family = "lato",
  #p_fontface = "italic",
  p_color  = viridis::mako(1, begin = 1),
  s_x      = 1,
  s_y      = 0.8,
  s_width  = 1.1,
  s_height = 1.15,
  h_fill   = viridis::mako(1, begin = 0.62),
  h_color  = viridis::mako(1, begin = 1),
  dpi      = 600,
  filename = paste0(dir, "stomachr.png")
)

sticker_img <- image_read(paste0(dir, "stomachr.png"))
sticker_w   <- image_info(sticker_img)$width
sticker_h   <- image_info(sticker_img)$height


db <- image_read(paste0(dir, "db2.png"))
db <- image_convert(db, "PNG")
db <- image_scale(db, paste0(round(sticker_w * 0.5)))  # fits within sticker
offset_x <- round(sticker_w * 0)  # can now nudge left/right
db <- image_transparent(db, "white", fuzz = 10)
db <- image_colorize(db, opacity = 90, color = viridis::mako(1, begin = 1))
db <- image_fx(db, expression = "a*0.55", channel = "alpha") # db alpha
db <- image_scale(db, paste0(round(sticker_w * 1.1)))  # bigger db

offset_y <- round(sticker_h * 0.4)

final <- image_composite(sticker_img, db,
                         operator = "over",
                         offset   = paste0("+", offset_x, "+", offset_y))

final <- image_trim(final)
image_write(final, paste0(dir, "stomachr.png"))
file.copy(paste0(dir, "stomachr.png"), "man/figures/logo.png", overwrite = TRUE)





