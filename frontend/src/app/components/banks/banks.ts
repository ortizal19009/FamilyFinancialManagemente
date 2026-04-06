import { Component, OnInit, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { RouterModule } from '@angular/router';
import { ApiService } from '../../services/api.service';

@Component({
  selector: 'app-banks',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterModule],
  templateUrl: './banks.html',
  styleUrl: './banks.scss'
})
export class BanksComponent implements OnInit {
  private apiService = inject(ApiService);

  banks: any[] = [];
  accounts: any[] = [];
  familyMembers: any[] = [];

  newBank = {
    name: '',
    description: ''
  };

  newAccount = {
    bank_id: null,
    account_number: '',
    account_type: 'Ahorros',
    owner: '',
    current_balance: 0
  };

  loadingBank = false;
  loadingAccount = false;
  savingBankId: number | null = null;
  deletingBankId: number | null = null;
  savingAccountId: number | null = null;
  deletingAccountId: number | null = null;
  successMsg = '';
  errorMsg = '';
  editingBankId: number | null = null;
  editingAccountId: number | null = null;
  editingBank = {
    name: '',
    description: ''
  };
  editingAccount = {
    bank_id: null,
    account_number: '',
    account_type: 'Ahorros',
    owner: '',
    current_balance: 0
  };

  ngOnInit() {
    this.loadData();
  }

  loadData() {
    this.apiService.getBanks().subscribe(data => this.banks = data);
    this.apiService.getBankAccounts().subscribe(data => this.accounts = data);
    this.apiService.getFamilyMembers().subscribe(data => this.familyMembers = data);
  }

  onCreateBank() {
    this.loadingBank = true;
    this.apiService.createBank(this.newBank).subscribe({
      next: () => {
        this.successMsg = 'Banco registrado correctamente';
        this.newBank = { name: '', description: '' };
        this.loadData();
        this.loadingBank = false;
        setTimeout(() => this.successMsg = '', 3000);
      },
      error: () => {
        this.errorMsg = 'Error al registrar el banco';
        this.loadingBank = false;
        setTimeout(() => this.errorMsg = '', 3000);
      }
    });
  }

  startEditBank(bank: any) {
    this.editingBankId = bank.id;
    this.editingBank = {
      name: bank.name ?? '',
      description: bank.description ?? ''
    };
  }

  cancelEditBank() {
    this.editingBankId = null;
    this.editingBank = { name: '', description: '' };
  }

  onUpdateBank() {
    if (this.editingBankId === null) {
      return;
    }

    this.savingBankId = this.editingBankId;
    this.apiService.updateBank(this.editingBankId, this.editingBank).subscribe({
      next: () => {
        this.successMsg = 'Banco actualizado correctamente';
        this.cancelEditBank();
        this.loadData();
        this.savingBankId = null;
        setTimeout(() => this.successMsg = '', 3000);
      },
      error: (error) => {
        this.errorMsg = error?.error?.msg || 'Error al actualizar el banco';
        this.savingBankId = null;
        setTimeout(() => this.errorMsg = '', 3000);
      }
    });
  }

  onDeleteBank(bank: any) {
    const confirmed = window.confirm(`¿Deseas eliminar el banco "${bank.name}"?`);
    if (!confirmed) {
      return;
    }

    this.deletingBankId = bank.id;
    this.apiService.deleteBank(bank.id).subscribe({
      next: () => {
        this.successMsg = 'Banco eliminado correctamente';
        if (this.editingBankId === bank.id) {
          this.cancelEditBank();
        }
        this.loadData();
        this.deletingBankId = null;
        setTimeout(() => this.successMsg = '', 3000);
      },
      error: (error) => {
        this.errorMsg = error?.error?.msg || 'Error al eliminar el banco';
        this.deletingBankId = null;
        setTimeout(() => this.errorMsg = '', 4000);
      }
    });
  }

  onCreateAccount() {
    this.loadingAccount = true;
    this.apiService.createBankAccount(this.newAccount).subscribe({
      next: () => {
        this.successMsg = 'Cuenta bancaria registrada correctamente';
        this.newAccount = { bank_id: null, account_number: '', account_type: 'Ahorros', owner: '', current_balance: 0 };
        this.loadData();
        this.loadingAccount = false;
        setTimeout(() => this.successMsg = '', 3000);
      },
      error: () => {
        this.errorMsg = 'Error al registrar la cuenta';
        this.loadingAccount = false;
        setTimeout(() => this.errorMsg = '', 3000);
      }
    });
  }

  startEditAccount(account: any) {
    this.editingAccountId = account.id;
    this.editingAccount = {
      bank_id: account.bank_id ?? null,
      account_number: account.account_number ?? '',
      account_type: account.account_type ?? 'Ahorros',
      owner: account.owner ?? '',
      current_balance: account.current_balance ?? 0
    };
  }

  cancelEditAccount() {
    this.editingAccountId = null;
    this.editingAccount = {
      bank_id: null,
      account_number: '',
      account_type: 'Ahorros',
      owner: '',
      current_balance: 0
    };
  }

  onUpdateAccount() {
    if (this.editingAccountId === null) {
      return;
    }

    this.savingAccountId = this.editingAccountId;
    this.apiService.updateBankAccount(this.editingAccountId, this.editingAccount).subscribe({
      next: () => {
        this.successMsg = 'Cuenta bancaria actualizada correctamente';
        this.cancelEditAccount();
        this.loadData();
        this.savingAccountId = null;
        setTimeout(() => this.successMsg = '', 3000);
      },
      error: (error) => {
        this.errorMsg = error?.error?.msg || 'Error al actualizar la cuenta';
        this.savingAccountId = null;
        setTimeout(() => this.errorMsg = '', 4000);
      }
    });
  }

  onDeleteAccount(account: any) {
    const confirmed = window.confirm(`¿Deseas cerrar la cuenta ${account.account_number}?`);
    if (!confirmed) {
      return;
    }

    this.deletingAccountId = account.id;
    this.apiService.deleteBankAccount(account.id).subscribe({
      next: () => {
        this.successMsg = 'Cuenta cerrada correctamente';
        if (this.editingAccountId === account.id) {
          this.cancelEditAccount();
        }
        this.loadData();
        this.deletingAccountId = null;
        setTimeout(() => this.successMsg = '', 3000);
      },
      error: (error) => {
        this.errorMsg = error?.error?.msg || 'Error al cerrar la cuenta';
        this.deletingAccountId = null;
        setTimeout(() => this.errorMsg = '', 4000);
      }
    });
  }
}
