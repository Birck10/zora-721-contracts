// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import {Test} from "forge-std/Test.sol";
import {IMetadataRenderer} from "../src/interfaces/IMetadataRenderer.sol";
import "../src/ZoraNFTCreatorV2.sol";
import "../src/ZoraFeeManager.sol";
import "../src/ZoraNFTCreatorProxy.sol";
import {MockMetadataRenderer} from "./metadata/MockMetadataRenderer.sol";
import {FactoryUpgradeGate} from "../src/FactoryUpgradeGate.sol";
import {IERC721AUpgradeable} from "erc721a-upgradeable/IERC721AUpgradeable.sol";

contract ZoraNFTCreatorV2Test is Test {
    address public constant DEFAULT_OWNER_ADDRESS = address(0x23499);
    address payable public constant DEFAULT_FUNDS_RECIPIENT_ADDRESS =
        payable(address(0x21303));
    address payable public constant DEFAULT_ZORA_DAO_ADDRESS =
        payable(address(0x999));
    ERC721Drop public dropImpl;
    ZoraNFTCreatorV2 public creator;
    EditionMetadataRenderer public editionMetadataRenderer;
    DropMetadataRenderer public dropMetadataRenderer;

    function setUp() public {
        vm.prank(DEFAULT_ZORA_DAO_ADDRESS);
        ZoraFeeManager feeManager = new ZoraFeeManager(
            500,
            DEFAULT_ZORA_DAO_ADDRESS
        );
        vm.prank(DEFAULT_ZORA_DAO_ADDRESS);
        dropImpl = new ERC721Drop(
            feeManager,
            address(1234),
            FactoryUpgradeGate(address(0)),
            address(0)
        );
        editionMetadataRenderer = new EditionMetadataRenderer();
        dropMetadataRenderer = new DropMetadataRenderer();
        ZoraNFTCreatorV2 impl = new ZoraNFTCreatorV2(
            address(dropImpl),
            editionMetadataRenderer,
            dropMetadataRenderer
        );
        creator = ZoraNFTCreatorV2(
            address(
                new ZoraNFTCreatorProxy(
                    address(impl),
                    abi.encodeWithSelector(ZoraNFTCreatorV2.initialize.selector)
                )
            )
        );
    }

    function test_CreateEdition() public {
        address deployedEdition = creator.createEdition(
            "name",
            "symbol",
            100,
            500,
            DEFAULT_FUNDS_RECIPIENT_ADDRESS,
            DEFAULT_FUNDS_RECIPIENT_ADDRESS,
            IERC721Drop.SalesConfiguration({
                publicSaleStart: 0,
                publicSaleEnd: type(uint64).max,
                presaleStart: 0,
                presaleEnd: 0,
                publicSalePrice: 0.1 ether,
                maxSalePurchasePerAddress: 0,
                presaleMerkleRoot: bytes32(0)
            }),
            "desc",
            "animation",
            "image"
        );
        ERC721Drop drop = ERC721Drop(payable(deployedEdition));
        vm.startPrank(DEFAULT_FUNDS_RECIPIENT_ADDRESS);
        vm.deal(DEFAULT_FUNDS_RECIPIENT_ADDRESS, 10 ether);
        drop.purchase{value: 1 ether}(10);
        assertEq(drop.totalSupply(), 10);
    }

    function test_CreateDrop() public {
        address deployedDrop = creator.createDrop(
            "name",
            "symbol",
            DEFAULT_FUNDS_RECIPIENT_ADDRESS,
            1000,
            100,
            DEFAULT_FUNDS_RECIPIENT_ADDRESS,
            IERC721Drop.SalesConfiguration({
                publicSaleStart: 0,
                publicSaleEnd: type(uint64).max,
                presaleStart: 0,
                presaleEnd: 0,
                publicSalePrice: 0,
                maxSalePurchasePerAddress: 0,
                presaleMerkleRoot: bytes32(0)
            }),
            "metadata_uri",
            "metadata_contract_uri"
        );
        ERC721Drop drop = ERC721Drop(payable(deployedDrop));
        drop.purchase(10);
        assertEq(drop.totalSupply(), 10);
    }

    function test_CreateGenericDrop() public {
        MockMetadataRenderer mockRenderer = new MockMetadataRenderer();
        address deployedDrop = creator.setupDropsContract(
            "name",
            "symbol",
            DEFAULT_FUNDS_RECIPIENT_ADDRESS,
            1000,
            100,
            DEFAULT_FUNDS_RECIPIENT_ADDRESS,
            IERC721Drop.SalesConfiguration({
                publicSaleStart: 0,
                publicSaleEnd: type(uint64).max,
                presaleStart: 0,
                presaleEnd: 0,
                publicSalePrice: 0,
                maxSalePurchasePerAddress: 0,
                presaleMerkleRoot: bytes32(0)
            }),
            mockRenderer,
            ""
        );
        ERC721Drop drop = ERC721Drop(payable(deployedDrop));
        ERC721Drop.SaleDetails memory saleDetails = drop.saleDetails();
        assertEq(saleDetails.publicSaleStart, 0);
        assertEq(saleDetails.publicSaleEnd, type(uint64).max);

        vm.expectRevert(
            IERC721AUpgradeable.URIQueryForNonexistentToken.selector
        );
        drop.tokenURI(1);
        assertEq(drop.contractURI(), "DEMO");
        drop.purchase(1);
        assertEq(drop.tokenURI(1), "DEMO");
    }
}
