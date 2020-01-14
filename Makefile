.PHONY: install
.PHONY: uninstall

INSTALL_DIR=~/.local/bin

install:
	cp ./wofi-pubs.sh $(INSTALL_DIR)/wofi-pubs.sh
	cp ./parse-bib-file $(INSTALL_DIR)/parse-bib-file
	cp ./wofi-papis.sh $(INSTALL_DIR)/wofi-papis.sh
	cp ./pubs_to_dptrp1 $(INSTALL_DIR)/pubs_to_dptrp1
	chmod +x $(INSTALL_DIR)/wofi-pubs.sh
	chmod +x $(INSTALL_DIR)/parse-bib-file
	chmod +x $(INSTALL_DIR)/wofi-papis.sh
	chmod +x $(INSTALL_DIR)/pubs_to_dptrp1

uninstall:
	rm $(INSTALL_DIR)/wofi-pubs.sh
	rm $(INSTALL_DIR)/parse-bib-file
	rm $(INSTALL_DIR)/wofi-papis.sh
	rm $(INSTALL_DIR)/pubs_to_dptrp1

