"""Size sweep for Tiny Tapeout: 32 words x 8 bits, 1 word(s) per row (32 rows)."""
word_size = 8
num_words = 32
human_byte_size = "{:.0f}kbytes".format((word_size * num_words)/1024/8)
write_size = 8
words_per_row = 1
num_rw_ports = 1
num_r_ports = 0
num_w_ports = 0
ports_human = '1rw'
num_spare_cols = 1
num_spare_rows = 1
num_sim_threads = 1
import os
exec(open(os.path.join(os.path.dirname(__file__), 'sky130_sram_common.py')).read())
tech_file = "tech_custom_cell"
output_name = "tt_sram_8x32_wpr1"
output_path = "macro/tt_sram_8x32_wpr1"
