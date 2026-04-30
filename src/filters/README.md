# filters

## API

- **`ycbcr_to_rgb`** (Function) — 


- **`clamp_byte_from_double`** (Function) — 


- **`row_byte_width`** (Function) — 


- **`predictor_sample_count`** (Function) — 


- **`png_bytes_per_pixel`** (Function) — 


- **`reconstruct_tiff_predictor`** (Function) — 


- **`reconstruct_png_predictor`** (Function) — 


- **`reconstruct_png_row`** (Function) — 


- **`paeth_predictor`** (Function) — 


- **`build_empty_decode_parms`** (Function) — 


- **`abs_int`** (Function) — 


- **`unpack_tiff_row_samples`** (Function) — 


- **`reconstruct_tiff_row_samples`** (Function) — 


- **`pack_tiff_row_samples`** (Function) — 


- **`JpegQuantTable`** (Struct) — 


- **`JpegHuffmanTable`** (Struct) — 


- **`JpegComponent`** (Struct) — 


- **`JpegFrame`** (Struct) — 


- **`JpegPlane`** (Struct) — 


- **`JpegDecoder`** (Struct) — 


- **`JpegEntropyReader`** (Struct) — 


- **`decode_dct`** (Function) — 


- **`new`** (Function) — 


- **`decode`** (Function) — 


- **`decode_scan`** (Function) — 


- **`require_marker`** (Function) — 


- **`next_marker`** (Function) — 


- **`read_u8`** (Function) — 


- **`read_u16`** (Function) — 


- **`read_segment_bounds`** (Function) — 


- **`skip_marker_segment`** (Function) — 


- **`parse_app14_adobe`** (Function) — 


- **`parse_dqt`** (Function) — 


- **`parse_dht`** (Function) — 


- **`parse_sof0`** (Function) — 


- **`parse_dri`** (Function) — 


- **`parse_sos`** (Function) — 


- **`validate_frame`** (Function) — 


- **`decode_frame_planes`** (Function) — 


- **`decode_block`** (Function) — 


- **`require_quant_table`** (Function) — 


- **`require_dc_table`** (Function) — 


- **`require_ac_table`** (Function) — 


- **`consume_eoi_after_scan`** (Function) — 


- **`interleave_output`** (Function) — 


- **`resolve_color_transform`** (Function) — 


- **`read_bit`** (Function) — 


- **`read_bits`** (Function) — 


- **`receive_extend`** (Function) — 


- **`read_entropy_byte`** (Function) — 


- **`align_to_byte`** (Function) — 


- **`consume_restart_marker`** (Function) — 


- **`decode_symbol`** (Function) — 


- **`build_jpeg_huffman_table`** (Function) — 


- **`find_jpeg_component`** (Function) — 


- **`create_jpeg_planes`** (Function) — 


- **`put_jpeg_block`** (Function) — 


- **`dequantize_and_idct`** (Function) — 


- **`idct_8x8`** (Function) — 


- **`interleave_grayscale`** (Function) — 


- **`interleave_three_component`** (Function) — 


- **`sample_jpeg_plane`** (Function) — 


- **`is_pdf_hex_white_space`** (Function) — 


- **`predictor_context`** (Function) — 


- **`jpeg_byte`** (Function) — 


- **`ceil_div`** (Function) — 


- **`reset_int_array`** (Function) — 


- **`apply_predictor`** (Function) — 


- **`HuffmanTable`** (Struct) — 


- **`DynamicHuffmanTables`** (Struct) — 


- **`build_fixed_literal_length_table`** (Function) — 


- **`build_fixed_distance_table`** (Function) — 


- **`build_huffman_table`** (Function) — 


- **`build_dynamic_huffman_tables`** (Function) — 


- **`decode_code_lengths`** (Function) — 


- **`decode_fixed_length`** (Function) — 


- **`decode_length_symbol`** (Function) — 


- **`decode_fixed_distance`** (Function) — 


- **`decode_distance_symbol`** (Function) — 


- **`read_optional_bits`** (Function) — 


- **`reverse_bits`** (Function) — 


- **`decode_stored_block`** (Function) — 


- **`byte_position`** (Function) — 


- **`MsbBitReader`** (Struct) — 


- **`LzwDecoder`** (Struct) — 


- **`decode_lzw`** (Function) — 


- **`decode_code`** (Function) — 


- **`record_sequence`** (Function) — 


- **`extend_table`** (Function) — 


- **`reset_state`** (Function) — 


- **`read_code`** (Function) — 


- **`resolve_sequence`** (Function) — 


- **`build_current_sequence`** (Function) — 


- **`maybe_grow_code_width`** (Function) — 


- **`read_lzw_early_change`** (Function) — 


- **`build_lzw_table`** (Function) — 


- **`to_text`** (Function) — 


- **`adler32`** (Function) — 


- **`DecodeParams`** (Struct) — 


- **`FilterSpec`** (Struct) — 


- **`validate_adler32`** (Function) — 


- **`decode_flate`** (Function) — 


- **`decode_zlib_stream`** (Function) — 


- **`read_u32_be`** (Function) — 


- **`decode_fixed_huffman_block`** (Function) — 


- **`decode_dynamic_huffman_block`** (Function) — 


- **`decode_huffman_block`** (Function) — 


- **`copy_back_reference`** (Function) — 


- **`read_u16_le`** (Function) — 


- **`parse_zlib_stream`** (Function) — 


- **`decode_pdf_file_structure_stream_bytes`** (Function) — 


- **`decode_ascii85_terminated`** (Function) — 


- **`decode_ascii85_group`** (Function) — 


- **`decode_ascii85_value`** (Function) — 


- **`is_ascii85_impossible`** (Function) — 


- **`is_pdf_ascii85_white_space`** (Function) — 


- **`hex_digit_value`** (Function) — 


- **`ZlibStream`** (Struct) — 
- **`LsbBitReader`** (Struct) — 
- **`FilterName`** (Enum) — 
- **`decode_deflate`** (Function) — 
- **`decode_run_length`** (Function) — 
- **`decode_ascii85`** (Function) — 
- **`decode_ascii_hex`** (Function) — 
- **`PredictorContext`** (Struct) —
