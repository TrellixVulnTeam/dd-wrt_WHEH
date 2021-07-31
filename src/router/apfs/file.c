// SPDX-License-Identifier: GPL-2.0
/*
 * Copyright (C) 2018 Ernesto A. Fernández <ernesto.mnd.fernandez@gmail.com>
 */

#include "apfs.h"

const struct file_operations apfs_file_operations = {
	.llseek		= generic_file_llseek,
	.read_iter	= generic_file_read_iter,
	.write_iter	= generic_file_write_iter,
	.mmap		= generic_file_readonly_mmap,
	.open		= generic_file_open,
	.unlocked_ioctl	= apfs_file_ioctl,
};

const struct inode_operations apfs_file_inode_operations = {
	.getattr	= apfs_getattr,
	.listxattr	= apfs_listxattr,
	.setattr	= apfs_setattr,
	.update_time	= apfs_update_time,
};
