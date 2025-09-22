use audio::wav;
use fmt;
use io;
use os;

export fn main() void = {
	const reader = wav::newreader(os::stdin)!;
	fmt::println("format_type", reader.header.format_type,
		"n_channels", reader.header.n_channels,
		"sample_rate", reader.header.sample_rate,
		"average_bps", reader.header.average_bps,
		"block_align", reader.header.block_align,
		"bits_per_sample", reader.header.bits_per_sample)!;
	match (io::copy(os::stdout_file, &reader)) {
	case let err: io::error =>
		fmt::fatal("Error:", io::strerror(err));
	case size =>
		yield;
	};
};
