library(hexSticker)
library(showtext)
library(magick)

font_add_google("Lato", "lato")
showtext_auto()

dir <- "/Users/maxlindmark/Dropbox/max-work/R/stomachr/inst/figures/"

# Recolor fish
fish <- image_read(paste0(dir, "fish.png"))
fish <- image_convert(fish, "PNG")
fish <- image_transparent(fish, "white", fuzz = 20)
fish_mask <- fish
fish <- image_colorize(fish, opacity = 100, color = viridis::mako(1, begin = 0.55)) # fish color
fish <- image_composite(fish, fish_mask, operator = "DstIn") # restore alpha, remove color rectangle
image_write(fish, paste0(dir, "fish_mako.png"))

sticker(
  paste0(dir, "fish_mako.png"),
  package  = "stomachr",
  p_size   = 55,
  p_y      = 1.4,
  p_family = "lato",
  p_fontface = "bold",
  #p_fontface = "italic",
  p_color  = viridis::mako(1, begin = 1.0),
  #p_color  = "#FAF9F6",
  s_x      = 1,
  s_y      = 0.8,
  s_width  = 1.1,
  s_height = 1.15,
  h_fill   = viridis::mako(1, begin = 0.489322),
  h_color  = viridis::mako(1, begin = 0.1712643),
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
db <- image_transparent(db, "white", fuzz = 20)
db_mask <- db
db <- image_colorize(db, opacity = 100, color = viridis::mako(1, begin = 0.55))
db <- image_composite(db, db_mask, operator = "DstIn") # restore alpha
db <- image_scale(db, paste0(round(sticker_w * 1.1)))  # bigger db

offset_y <- round(sticker_h * 0.4)

final <- image_composite(sticker_img, db,
                         operator = "over",
                         offset   = paste0("+", offset_x, "+", offset_y))

final <- image_trim(final)
image_write(final, paste0(dir, "stomachr.png"))
file.copy(paste0(dir, "stomachr.png"), "man/figures/logo.png", overwrite = TRUE)





