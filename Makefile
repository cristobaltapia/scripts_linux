.PHONY: install
.PHONY: uninstall

install:
	cp ./wofi_pubs.sh ~/.local/bin/wofi_pubs.sh
	chmod +x ~/.local/bin/wofi_pubs.sh

uninstall:
	rm ~/.local/bin/wofi_pubs.sh

