// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

contract Market is IERC721Receiver {
    uint256 public price = 1 ether;

    enum ListingStatus {
        Active,
        Sold,
        Cancelled
    }

    struct Listing {
        ListingStatus status;
        address seller;
        address token;
        uint256 tokenID;
        uint256 price;
    }

    event Listed(
        uint256 listingID,
        address seller,
        address token,
        uint256 tokenID,
        uint256 price
    );

    event Sale(
        uint256 listingID,
        address buyer,
        address token,
        uint256 tokenID,
        uint256 price
    );

    event Cancel(uint256 listingID, address seller);

    uint256 private _listingID = 0;
    mapping(uint256 => Listing) private _listings;

    function listToken(
        address token,
        uint256 tokenID,
        uint256 price
    ) external {
        IERC721(token).transferFrom(msg.sender, address(this), tokenID);

        Listing memory listing = Listing(
            ListingStatus.Active,
            msg.sender,
            token,
            tokenID,
            price
        );
        _listingID++;
        _listings[_listingID] = listing;

        emit Listed(_listingID, msg.sender, token, tokenID, price);
    }

    function getListing(uint256 listingID)
        public
        view
        returns (Listing memory)
    {
        return _listings[listingID];
    }

    function buyToken(uint256 listingID) external payable {
        Listing storage listing = _listings[listingID];

        require(msg.sender != listing.seller, "Seller cannot be buyer.");
        require(
            listing.status == ListingStatus.Active,
            "Listing is not active."
        );
        require(msg.value >= listing.price, "Insufficient payment.");

        listing.status = ListingStatus.Sold;

        IERC721(listing.token).transferFrom(
            address(this),
            msg.sender,
            listing.tokenID
        );
        payable(listing.seller).transfer(listing.price);

        emit Sale(
            listingID,
            msg.sender,
            listing.token,
            listing.tokenID,
            listing.price
        );
    }

    function cancel(uint256 listingID) public {
        Listing storage listing = _listings[listingID];
        require(
            msg.sender == listing.seller,
            "Only seller can cancel listing."
        );
        require(
            listing.status == ListingStatus.Active,
            "Listing is not active."
        );

        listing.status = ListingStatus.Cancelled;
        IERC721(listing.token).transferFrom(
            address(this),
            msg.sender,
            listing.tokenID
        );

        emit Cancel(listingID, listing.seller);
    }

    function setPrice(uint256 _newPrice) public onlyOwner {
        price = _newPrice;
    }

    function onERC721Received(
        address operator,
        address,
        uint256 tokenId,
        bytes calldata
    ) external override returns (bytes4) {
        Listing memory listing = Listing(
            ListingStatus.Active,
            operator,
            msg.sender,
            tokenId,
            price
        );

        _listingID++;
        _listings[_listingID] = listing;

        emit Listed(_listingID, operator, msg.sender, tokenId, price);

        return this.onERC721Received.selector;
    }
}
