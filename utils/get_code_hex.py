import sys


def get_code_hex(contract_path, separator=None):
    with open(contract_path, "r") as contract_file:
        content = contract_file.read()

        # If separator is provided, split the content and return hex strings for each part
        if separator:
            parts = content.split(separator)
            return [bytes(part, "UTF-8").hex() for part in parts]
        else:
            return [bytes(content, "UTF-8").hex()]


def main():
    if len(sys.argv) < 2:
        print(
            "Usage: python get_code_hex.py <contract_path> [--separator <SEPARATOR_VALUE>]"
        )
        sys.exit()

    separator = None
    if "--separator" in sys.argv:
        separator_index = sys.argv.index("--separator")
        if separator_index + 1 < len(sys.argv):
            separator = sys.argv[separator_index + 1]
        else:
            print("Error: --separator flag requires a value")
            sys.exit(1)

    print(get_code_hex(sys.argv[1], separator))


if __name__ == "__main__":
    main()
