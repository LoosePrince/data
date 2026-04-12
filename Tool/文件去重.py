import os
import hashlib
import shutil
from collections import defaultdict

def get_file_hash(file_path, block_size=65536):
    """计算文件的 SHA-256 哈希值"""
    hasher = hashlib.sha256()
    with open(file_path, 'rb') as f:
        for block in iter(lambda: f.read(block_size), b""):
            hasher.update(block)
    return hasher.hexdigest()

def get_hardlink_count(file_path):
    """返回文件的硬链接数量"""
    try:
        stat_info = os.stat(file_path)
        return stat_info.st_nlink  # 返回硬链接数量
    except OSError as e:
        print(f"获取硬链接计数时出错: {e}")
        return 1

def find_duplicate_files(directory):
    """查找重复文件，返回哈希值对应的文件列表，并排除已硬链接的文件"""
    files_by_size = defaultdict(list)
    duplicates = defaultdict(list)
    hardlinked_files = defaultdict(list)  # 存储硬链接文件的列表

    # 按文件大小分组
    for root, _, files in os.walk(directory):
        for file in files:
            file_path = os.path.join(root, file)
            try:
                file_size = os.path.getsize(file_path)
                files_by_size[file_size].append(file_path)
            except OSError:
                pass
    
    # 对于大小相同的文件，计算哈希值以确认内容是否相同
    for file_list in files_by_size.values():
        if len(file_list) > 1:
            hashes = defaultdict(list)
            for file_path in file_list:
                file_hash = get_file_hash(file_path)
                hashes[file_hash].append(file_path)
            
            for hash_val, paths in hashes.items():
                if len(paths) > 1:
                    for path in paths:
                        if get_hardlink_count(path) > 1:
                            hardlinked_files[hash_val].append(path)  # 标记为硬链接文件
                        else:
                            duplicates[hash_val].append(path)
    
    return duplicates, hardlinked_files

def unlock_file(file_path):
    """尝试解锁文件并修改权限"""
    try:
        # 修改文件权限为可读写
        os.chmod(file_path, 0o777)
        print(f"已解锁文件: {file_path}")
    except PermissionError:
        print(f"无法解锁文件: {file_path}")
        return False
    return True

def convert_to_hardlink(original_path, target_path):
    """将重复文件转换为硬链接"""
    try:
        os.remove(target_path)  # 删除原文件
        os.link(original_path, target_path)  # 创建硬链接
        print(f"已将 {target_path} 转为硬链接，指向 {original_path}")
    except OSError as e:
        print(f"转换为硬链接时出错: {e}")

def convert_to_symlink(original_path, target_path):
    """将重复文件转换为符号链接"""
    try:
        os.remove(target_path)  # 删除原文件
        os.symlink(original_path, target_path)  # 创建符号链接
        print(f"已将 {target_path} 转为符号链接，指向 {original_path}")
    except OSError as e:
        print(f"转换为符号链接时出错: {e}")

def convert_to_softlink(original_path, target_path):
    """将重复文件转换为软链接（符号链接的另一种叫法）"""
    convert_to_symlink(original_path, target_path)

def remove_duplicates(duplicates, action):
    """根据选择的操作处理重复文件"""
    for file_list in duplicates.values():
        for file_path in file_list[1:]:  # 保留第一个，处理其他
            try:
                if unlock_file(file_path):
                    if action == 'delete':
                        os.remove(file_path)
                        print(f"已删除: {file_path}")
                    elif action == 'hardlink':
                        convert_to_hardlink(file_list[0], file_path)
                    elif action == 'symlink' or action == 'softlink':
                        convert_to_symlink(file_list[0], file_path)
                    elif action == 'delete_all':
                        os.remove(file_path)
                        print(f"已删除: {file_path}")
            except OSError as e:
                print(f"操作 {file_path} 时出错: {e}")

def main():
    directory = os.getcwd()  # 当前目录
    print(f"正在扫描目录: {directory}\n")
    duplicates, hardlinked_files = find_duplicate_files(directory)
    
    if duplicates or hardlinked_files:
        print("找到以下重复文件:")
        for hash_val, paths in duplicates.items():
            print(f"\n重复文件 ({hash_val}):")
            for path in paths:
                print(f"  {path}")
            print("-")
        
        if hardlinked_files:
            print("\n以下文件为硬链接，已排除:")
            for hash_val, paths in hardlinked_files.items():
                print(f"硬链接文件 ({hash_val}):")
                for path in paths:
                    print(f"  {path}")
            print("-")

        # 提供选项
        print("请选择处理方式:")
        print("1. 删除重复文件")
        print("2. 转为硬链接")
        print("3. 转为符号链接（软链接）")
        print("4. 全部删除")
        print("5. 取消")
        choice = input("请输入选项 (1/2/3/4/5): ").strip()

        action = None
        if choice == '1':
            action = 'delete'
        elif choice == '2':
            action = 'hardlink'
        elif choice == '3':
            action = 'symlink'  # 软链接和符号链接是同一种方式
        elif choice == '4':
            action = 'delete_all'
        
        if action:
            remove_duplicates(duplicates, action)
            print("操作完成。")
        else:
            print("取消操作。")
    else:
        print("未找到重复文件。")

if __name__ == "__main__":
    main()
