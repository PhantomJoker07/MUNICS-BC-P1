//SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

contract FabricaContract {
    uint private idDigits = 16;

    struct Product{
    string nombre;
    uint identificacion;
    }
    Product [] public productos;
    event NuevoProducto (uint256 ArrayProductoId, string nombre, uint id);
    mapping (uint => address) public productoAPropietario;
    mapping (address => uint) public propietarioAProducto;

    function _crearProducto (string memory _nombre, uint _id ) private {
    productos.push(Product(_nombre,_id));
    emit NuevoProducto(productos.length - 1, _nombre, _id);
    }

    function _generarIdAleatorio (string memory _str) private view returns (uint){
    uint idModulus = 10** idDigits;
    uint rand = uint (keccak256(abi.encodePacked(_str)));
    return rand % idModulus;
    }

    function propiedad (uint productoId) public{
        productoAPropietario [productoId] = msg.sender; 
        propietarioAProducto [msg.sender] = productoId; 
    }

    function crearProductoAleatorio (string memory _nombre) public {
        uint randId = _generarIdAleatorio(_nombre);
        _crearProducto(_nombre, randId);
        //propiedad(randId);    //This is needed for testing
    }

    function getProductosPorPropietario(address _propietario) view external returns (uint [] memory){
        uint contador = 0;
        uint[] memory tempResultado = new uint[](productos.length);
        for (uint i = 0; i < productos.length; i++){
            uint _prod = productos[i].identificacion;
            address prodOwner = productoAPropietario[_prod];
            if (prodOwner == _propietario){
                tempResultado [contador] = _prod;
                contador++;
            }    
        }
        uint[] memory resultado = new uint[](contador);
        for (uint i = 0; i < contador; i++){resultado[i] = tempResultado[i];}
        return resultado;
    }

}