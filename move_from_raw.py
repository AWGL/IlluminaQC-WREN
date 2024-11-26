import os
import shutil
import time
from datetime import datetime, timedelta
from pathlib import Path

# define the age threshold for directory movement
threshold_days = 8  # configurable

# define base raw and archive directories
raw_dir = '/data_heath/raw'
archive_dir = '/data_heath/archive'
archive_qc = '/data_heath/archive/quality_temp'

# get today's date
today = datetime.now()

max_moves = 20
move_count = 0

# iterate over raw_dir's subdirectories
for subdir in os.listdir(raw_dir):

	subdir_path = Path(raw_dir) / subdir

	# check if it's a directory
	if subdir_path.is_dir():

		# iterate over sequencing data directories within raw_dir subdirectories
		for seq_dir in os.listdir(subdir_path):

			seq_dir_path = subdir_path / seq_dir

			# check if it's a directory and it has CopyComplete.txt file
			if seq_dir_path.is_dir() and (seq_dir_path / 'ready_for_move.txt').exists():
				# extract date from directory name
				dir_date_str = seq_dir[:6]  # get the first six characters

				# convert date from string to datetime object
				try:
					dir_date = datetime.strptime(dir_date_str, "%y%m%d")
				except:

					print(f'Cannot convert folder ({seqdir}) to date')
					continue

				# check if the directory is older than threshold_days
				if (today - dir_date).days > threshold_days:
					

					# construct the corresponding archive directory path
					archive_subdir_path = Path(archive_dir) / subdir
					new_seq_dir_path = archive_subdir_path / seq_dir

					archive_qc_subdir_path = Path(archive_qc) / subdir / seq_dir

					# ensure archive directory exists
					archive_subdir_path.mkdir(parents=True, exist_ok=True)

					# check if the directory doesn't already exist at the new location
					if not new_seq_dir_path.exists():

						# move the directory to the archive
						print('move', str(seq_dir_path),  str(archive_subdir_path))
						shutil.move(str(seq_dir_path), str(archive_subdir_path))

						if archive_qc_subdir_path.exists():
							print('delete', str(archive_qc_subdir_path))
							shutil.rmtree(str(archive_qc_subdir_path))
						
						time.sleep(120)						

						move_count = move_count + 1

						if move_count > max_moves:

							break


					else:
						print(f"Directory {seq_dir} already exists at the archive location.")

				else:
					print(f"Directory {seq_dir} less than {threshold_days} days old - not moving.")

