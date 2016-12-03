install:
	-./dcmd clean
	./dcmd install
	./dcmd provision
	./dcmd init
	./dcmd dbdump