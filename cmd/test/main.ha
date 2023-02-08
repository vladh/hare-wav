use audio::wav;
use fmt;
use io;
use os;

export fn main() void = {
	const (header, reader) = wav::newreader(os::stdin)!;
	fmt::println("format_type", header.format_type,
		"n_channels", header.n_channels,
		"sample_rate", header.sample_rate,
		"average_bps", header.average_bps,
		"block_align", header.block_align,
		"bits_per_sample", header.bits_per_sample)!;
	match (io::copy(os::stdout_file, &reader)) {
	case let err: io::error =>
		fmt::fatal("Error:", io::strerror(err));
	case size =>
		yield;
	};
};
